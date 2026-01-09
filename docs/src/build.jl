# build.jl - Static site generator for Therapy.jl docs
#
# Generates a static site from Therapy.jl components for GitHub Pages deployment.
# Uses REAL Therapy.jl compilation for interactive Wasm demos.
#
# Usage:
#   julia --project=../.. docs/src/build.jl
#
# Output goes to docs/dist/

using Therapy

const DOCS_ROOT = dirname(@__FILE__)
const DIST_DIR = joinpath(dirname(DOCS_ROOT), "dist")

# Routes to generate (path => source file)
const ROUTES = [
    "/" => "routes/index.jl",
    "/getting-started/" => "routes/getting-started.jl",
]

# Interactive components - these are compiled to WebAssembly
# See the source files for the actual Julia code that becomes Wasm
include("components/InteractiveCounter.jl")
include("components/ThemeToggle.jl")

"""
Build the interactive counter using Therapy.jl's compile_component.
Returns the HTML, Wasm bytes, and hydration JS.
"""
function build_interactive_counter()
    println("  Compiling InteractiveCounter with Therapy.jl...")

    # Use container_selector to scope DOM queries to #counter-demo
    # This prevents conflicts with other data-hk attributes on the page
    compiled = compile_component(InteractiveCounter; container_selector="#counter-demo")

    println("    Wasm: $(length(compiled.wasm.bytes)) bytes")
    println("    Exports: $(join(compiled.wasm.exports, ", "))")

    return compiled
end

"""
Build the theme toggle using Therapy.jl's compile_component.
Returns the HTML, Wasm bytes, and hydration JS.
"""
function build_theme_toggle()
    println("  Compiling ThemeToggle with Therapy.jl...")

    # Use container_selector to scope DOM queries to #theme-toggle
    compiled = compile_component(ThemeToggle; container_selector="#theme-toggle")

    println("    Wasm: $(length(compiled.wasm.bytes)) bytes")
    println("    Exports: $(join(compiled.wasm.exports, ", "))")

    return compiled
end

"""
Generate a full HTML page with Tailwind CSS and dark mode support.
"""
function generate_page(component_fn; title="Therapy.jl Docs", counter_html="", counter_js="", theme_html="", theme_js="")
    # Get the rendered component HTML (use invokelatest for dynamic includes)
    content = render_to_string(Base.invokelatest(component_fn))

    # If we have counter HTML, inject it into the counter-demo div
    if !isempty(counter_html)
        content = replace(content,
            r"<div[^>]*id=\"counter-demo\"[^>]*>.*?</div>"s =>
            """<div id="counter-demo" class="bg-white/10 backdrop-blur rounded-xl p-8 max-w-md mx-auto">$counter_html</div>""")
    end

    # If we have theme toggle HTML, inject it into the theme-toggle div
    if !isempty(theme_html)
        content = replace(content,
            r"<div[^>]*id=\"theme-toggle\"[^>]*></div>"s =>
            """<div id="theme-toggle" class="ml-2">$theme_html</div>""")
    end

    # Combine all JS
    all_js = String[]
    if !isempty(counter_js)
        push!(all_js, counter_js)
    end
    if !isempty(theme_js)
        push!(all_js, theme_js)
    end
    combined_js = join(all_js, "\n\n")

    # Wrap in full HTML document
    """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(title)</title>

    <!-- Tailwind CSS from CDN -->
    <script src="https://cdn.tailwindcss.com"></script>

    <!-- Custom Tailwind config with dark mode -->
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

    <!-- Inter font -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <!-- Syntax highlighting -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">

    <style>
        html { scroll-behavior: smooth; }
        pre code { font-family: 'Fira Code', 'Monaco', 'Consolas', monospace; }
    </style>

    <!-- Initialize theme from localStorage before page renders -->
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
</head>
<body class="antialiased">
    $(content)

    <!-- Syntax highlighting -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>

    $(isempty(combined_js) ? "" : "<script>\n$combined_js\n</script>")
</body>
</html>
"""
end

"""
Build all static pages.
"""
function build()
    println("Building Therapy.jl documentation site...")
    println("Output directory: $DIST_DIR")

    # Clean and create dist directory
    rm(DIST_DIR, recursive=true, force=true)
    mkpath(DIST_DIR)
    mkpath(joinpath(DIST_DIR, "wasm"))

    # Build the interactive components using Therapy.jl compilation
    println("\n━━━ Compiling Interactive Components ━━━")
    compiled_counter = build_interactive_counter()
    compiled_theme = build_theme_toggle()

    # Write the Wasm files
    counter_wasm_path = joinpath(DIST_DIR, "app.wasm")
    write(counter_wasm_path, compiled_counter.wasm.bytes)
    println("  Wrote: $counter_wasm_path")

    theme_wasm_path = joinpath(DIST_DIR, "theme.wasm")
    write(theme_wasm_path, compiled_theme.wasm.bytes)
    println("  Wrote: $theme_wasm_path")

    # Generate theme toggle hydration with correct wasm path
    theme_js = replace(compiled_theme.hydration.js, "./app.wasm" => "./theme.wasm")

    # Generate each route
    println("\n━━━ Building Pages ━━━")
    for (route_path, source_file) in ROUTES
        println("  Building: $route_path")

        # Load the component module
        source_path = joinpath(DOCS_ROOT, source_file)
        component_fn = include(source_path)

        # Generate HTML
        route_title = if route_path == "/"
            "Therapy.jl - Reactive Web Framework for Julia"
        else
            "Therapy.jl - $(titlecase(basename(strip(route_path, '/'))))"
        end

        # For the home page, include both compiled components
        if route_path == "/"
            html = Base.invokelatest(generate_page, component_fn,
                title=route_title,
                counter_html=compiled_counter.html,
                counter_js=compiled_counter.hydration.js,
                theme_html=compiled_theme.html,
                theme_js=theme_js)
        else
            # Other pages only get the theme toggle
            html = Base.invokelatest(generate_page, component_fn,
                title=route_title,
                theme_html=compiled_theme.html,
                theme_js=theme_js)
        end

        # Determine output path
        if route_path == "/"
            output_path = joinpath(DIST_DIR, "index.html")
        else
            output_dir = joinpath(DIST_DIR, strip(route_path, '/'))
            mkpath(output_dir)
            output_path = joinpath(output_dir, "index.html")
        end

        write(output_path, html)
        println("    -> $(output_path)")
    end

    # Create a simple 404 page
    write(joinpath(DIST_DIR, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - Therapy.jl</title>
    <script src="https://cdn.tailwindcss.com"></script>
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

    # Create .nojekyll file for GitHub Pages
    write(joinpath(DIST_DIR, ".nojekyll"), "")

    println("\n━━━ Build Complete! ━━━")
    println("Files in dist/:")
    for (root, dirs, files) in walkdir(DIST_DIR)
        for file in files
            rel_path = relpath(joinpath(root, file), DIST_DIR)
            println("  $rel_path")
        end
    end
end

# Run build if this is the main script
if abspath(PROGRAM_FILE) == @__FILE__
    build()
end
