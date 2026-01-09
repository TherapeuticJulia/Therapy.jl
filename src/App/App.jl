# App.jl - Application framework for Therapy.jl
#
# Provides a clean API for building Therapy.jl applications with:
# - `dev(app)` - Development server with live reload
# - `build(app)` - Static site generation
#
# Example app.jl:
#   using Therapy
#   include("components/Layout.jl")
#   include("components/Counter.jl")
#
#   app = App(
#       routes = [
#           "/" => IndexPage,
#           "/about/" => AboutPage,
#       ],
#       interactive = [
#           Counter => "#counter-demo",
#       ],
#       title = "My App"
#   )
#
#   # Run with: julia app.jl dev|build
#   Therapy.run(app)

using HTTP
using Sockets

"""
Interactive component configuration.
Specifies where to inject compiled Wasm components.
"""
struct InteractiveComponent
    component::Function
    container_selector::String
end

"""
Application configuration.
"""
struct App
    routes::Vector{Pair{String, Function}}
    interactive::Vector{InteractiveComponent}
    title::String
    layout::Union{Function, Nothing}
    output_dir::String
    tailwind::Bool
    dark_mode::Bool

    function App(;
        routes::Vector = Pair{String, Function}[],
        interactive::Vector = [],
        title::String = "Therapy.jl App",
        layout::Union{Function, Nothing} = nothing,
        output_dir::String = "dist",
        tailwind::Bool = true,
        dark_mode::Bool = true
    )
        # Convert interactive to InteractiveComponent if needed
        ic = InteractiveComponent[]
        for item in interactive
            if item isa InteractiveComponent
                push!(ic, item)
            elseif item isa Pair
                push!(ic, InteractiveComponent(item.first, item.second))
            end
        end
        new(routes, ic, title, layout, output_dir, tailwind, dark_mode)
    end
end

"""
Compiled interactive component with Wasm and hydration.
"""
struct CompiledInteractive
    component::InteractiveComponent
    compiled::Any  # CompiledInteractive from Compile.jl
    html::String
    js::String
    wasm_bytes::Vector{UInt8}
    wasm_filename::String
end

"""
    compile_interactive_components(app::App) -> Vector{CompiledInteractive}

Compile all interactive components to Wasm.
"""
function compile_interactive_components(app::App)
    compiled = CompiledInteractive[]

    for (i, ic) in enumerate(app.interactive)
        println("  Compiling $(nameof(ic.component))...")

        # Compile with container selector for scoped DOM queries
        result = compile_component(ic.component; container_selector=ic.container_selector)

        # Generate unique wasm filename
        wasm_filename = "$(lowercase(string(nameof(ic.component)))).wasm"

        # Adjust hydration JS to use correct wasm path
        js = replace(result.hydration.js, "./app.wasm" => "./$wasm_filename")

        push!(compiled, CompiledInteractive(
            ic,
            result,
            result.html,
            js,
            result.wasm.bytes,
            wasm_filename
        ))

        println("    Wasm: $(length(result.wasm.bytes)) bytes")
    end

    return compiled
end

"""
Generate full HTML page with injected components.
"""
function generate_page(
    app::App,
    route_path::String,
    component_fn::Function,
    compiled_components::Vector{CompiledInteractive}
)
    # Render the route component
    content = render_to_string(Base.invokelatest(component_fn))

    # Inject compiled component HTML into containers
    for cc in compiled_components
        # Replace container placeholder with compiled HTML
        pattern = Regex("<div[^>]*id=\"$(lstrip(cc.component.container_selector, '#'))\"[^>]*>.*?</div>", "s")
        replacement = "<div id=\"$(lstrip(cc.component.container_selector, '#'))\">$(cc.html)</div>"
        content = replace(content, pattern => replacement)
    end

    # Combine all hydration JS
    all_js = join([cc.js for cc in compiled_components], "\n\n")

    # Generate page title
    page_title = if route_path == "/"
        app.title
    else
        "$(titlecase(replace(strip(route_path, '/'), "-" => " "))) - $(app.title)"
    end

    # Build HTML document
    html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(page_title)</title>
"""

    # Tailwind CSS
    if app.tailwind
        html *= """
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Inter', 'system-ui', 'sans-serif'],
                    }
                }
            }
        }
    </script>
"""
    end

    # Fonts and syntax highlighting
    html *= """
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'Fira Code', 'Monaco', 'Consolas', monospace; }
    </style>
"""

    # Dark mode init script
    if app.dark_mode
        html *= """
    <script>
        (function() {
            try {
                const saved = localStorage.getItem('therapy-theme');
                if (saved === 'dark' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                }
            } catch (e) {}
        })();
    </script>
"""
    end

    html *= """
</head>
<body class="antialiased">
$(content)
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>
"""

    # Add hydration JS
    if !isempty(all_js)
        html *= """
    <script>
$(all_js)
    </script>
"""
    end

    html *= """
</body>
</html>
"""

    return html
end

"""
    dev(app::App; port::Int=8080, host::String="127.0.0.1")

Start development server for a Therapy.jl application.
"""
function dev(app::App; port::Int=8080, host::String="127.0.0.1")
    println("\n━━━ Therapy.jl Dev Server ━━━")
    println("Compiling interactive components...")

    compiled_components = compile_interactive_components(app)

    println("\nStarting server on http://$host:$port")
    println("Press Ctrl+C to stop\n")

    server = HTTP.serve!(host, port) do request
        path = HTTP.URI(request.target).path
        path = path == "" ? "/" : path

        # Serve Wasm files
        for cc in compiled_components
            if path == "/$(cc.wasm_filename)"
                return HTTP.Response(200, ["Content-Type" => "application/wasm"], cc.wasm_bytes)
            end
        end

        # Match routes
        for (route_path, component_fn) in app.routes
            if path == route_path || (endswith(route_path, "/") && path == rstrip(route_path, '/'))
                try
                    # Only include components for their designated routes
                    # For now, include all components (can be refined later)
                    html = Base.invokelatest(generate_page, app, path, component_fn, compiled_components)
                    return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], html)
                catch e
                    @error "Error rendering page" exception=(e, catch_backtrace())
                    return HTTP.Response(500, "Error: $e")
                end
            end
        end

        return HTTP.Response(404, "Not Found: $path")
    end

    try
        wait(server)
    catch e
        if e isa InterruptException
            println("\nShutting down server...")
            close(server)
        else
            rethrow(e)
        end
    end
end

"""
    build(app::App)

Build static site from a Therapy.jl application.
"""
function build(app::App)
    println("\n━━━ Therapy.jl Static Build ━━━")
    println("Output: $(app.output_dir)")

    # Clean and create output directory
    rm(app.output_dir, recursive=true, force=true)
    mkpath(app.output_dir)

    # Compile interactive components
    println("\nCompiling interactive components...")
    compiled_components = compile_interactive_components(app)

    # Write Wasm files
    for cc in compiled_components
        wasm_path = joinpath(app.output_dir, cc.wasm_filename)
        write(wasm_path, cc.wasm_bytes)
        println("  Wrote: $(cc.wasm_filename)")
    end

    # Build pages
    println("\nBuilding pages...")
    for (route_path, component_fn) in app.routes
        println("  Building: $route_path")

        html = generate_page(app, route_path, component_fn, compiled_components)

        # Determine output path
        if route_path == "/"
            output_path = joinpath(app.output_dir, "index.html")
        else
            route_dir = joinpath(app.output_dir, strip(route_path, '/'))
            mkpath(route_dir)
            output_path = joinpath(route_dir, "index.html")
        end

        write(output_path, html)
    end

    # Create 404 page
    write(joinpath(app.output_dir, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - $(app.title)</title>
    $(app.tailwind ? "<script src=\"https://cdn.tailwindcss.com\"></script>" : "")
    <script>
        tailwind.config = { darkMode: 'class' }
        try {
            if (localStorage.getItem('therapy-theme') === 'dark') {
                document.documentElement.classList.add('dark');
            }
        } catch (e) {}
    </script>
</head>
<body class="antialiased bg-slate-50 dark:bg-slate-900">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-bold text-slate-300 dark:text-slate-600">404</h1>
            <p class="text-xl text-slate-600 dark:text-slate-400 mt-4">Page not found</p>
            <a href="/" class="inline-block mt-6 px-6 py-3 bg-violet-600 text-white rounded-lg hover:bg-violet-500 transition">
                Go Home
            </a>
        </div>
    </div>
</body>
</html>
""")

    # Create .nojekyll for GitHub Pages
    write(joinpath(app.output_dir, ".nojekyll"), "")

    println("\n━━━ Build Complete! ━━━")
    println("Files:")
    for (root, dirs, files) in walkdir(app.output_dir)
        for file in files
            rel_path = relpath(joinpath(root, file), app.output_dir)
            println("  $rel_path")
        end
    end
end

"""
    run(app::App)

Run the app based on command line arguments.
- `julia app.jl dev` - Start development server
- `julia app.jl build` - Build static site
"""
function run(app::App)
    if length(ARGS) == 0 || ARGS[1] == "build"
        build(app)
    elseif ARGS[1] == "dev"
        dev(app)
    else
        println("Usage: julia app.jl [dev|build]")
        println("  dev   - Start development server")
        println("  build - Build static site")
    end
end
