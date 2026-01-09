# build.jl - Static site generator for Therapy.jl docs
#
# Generates a static site from Therapy.jl components for GitHub Pages deployment.
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
    # Add more routes as they're created
    # "/api/signals/" => "routes/api/signals.jl",
    # "/examples/" => "routes/examples.jl",
]

"""
Generate a full HTML page with Tailwind CSS.
"""
function generate_page(component_fn; title="Therapy.jl Docs")
    # Get the rendered component HTML (use invokelatest for dynamic includes)
    content = render_to_string(Base.invokelatest(component_fn))

    # Wrap in full HTML document
    """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$(title)</title>

    <!-- Tailwind CSS from CDN (use build step for production) -->
    <script src="https://cdn.tailwindcss.com"></script>

    <!-- Custom Tailwind config -->
    <script>
        tailwind.config = {
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
        /* Custom styles */
        html {
            scroll-behavior: smooth;
        }

        pre code {
            font-family: 'Fira Code', 'Monaco', 'Consolas', monospace;
        }
    </style>
</head>
<body class="antialiased">
    $(content)

    <!-- Syntax highlighting -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-julia.min.js"></script>

    <!-- Hydration script for interactive counter demo -->
    <script type="module">
        // Load the counter WebAssembly module
        const counterDemo = document.getElementById('counter-demo');
        if (counterDemo) {
            try {
                const response = await fetch('/wasm/counter.wasm');
                const bytes = await response.arrayBuffer();

                // DOM update function for counter
                const counterDisplay = document.getElementById('counter-value');
                const imports = {
                    dom: {
                        update_text: (value) => {
                            if (counterDisplay) counterDisplay.textContent = String(value);
                        }
                    }
                };

                const { instance } = await WebAssembly.instantiate(bytes, imports);

                // Wire up increment/decrement handlers
                document.querySelectorAll('[data-handler]').forEach(el => {
                    const handlerName = el.dataset.handler;
                    const handler = instance.exports[handlerName];
                    if (handler) {
                        el.addEventListener('click', handler);
                    }
                });

                console.log('Counter Wasm module loaded');
            } catch (err) {
                console.warn('Failed to load counter Wasm:', err);
            }
        }
    </script>
</body>
</html>
"""
end

"""
Build the counter WebAssembly module for the interactive demo.
"""
function build_counter_wasm()
    println("  Building counter.wasm")

    # Helper to build Wasm sections properly
    bytes = UInt8[]

    # Magic and version
    append!(bytes, [0x00, 0x61, 0x73, 0x6d])  # \0asm
    append!(bytes, [0x01, 0x00, 0x00, 0x00])  # version 1

    # Type section (id=1): 2 types
    type_content = UInt8[
        0x02,                          # 2 types
        0x60, 0x01, 0x7f, 0x00,        # type 0: (i32) -> ()
        0x60, 0x00, 0x00,              # type 1: () -> ()
    ]
    push!(bytes, 0x01)  # section id
    push!(bytes, UInt8(length(type_content)))
    append!(bytes, type_content)

    # Import section (id=2): 1 import
    import_content = UInt8[
        0x01,  # 1 import
        0x03, 0x64, 0x6f, 0x6d,  # "dom"
        0x0b, 0x75, 0x70, 0x64, 0x61, 0x74, 0x65, 0x5f, 0x74, 0x65, 0x78, 0x74,  # "update_text"
        0x00, 0x00,  # func, type 0
    ]
    push!(bytes, 0x02)  # section id
    push!(bytes, UInt8(length(import_content)))
    append!(bytes, import_content)

    # Function section (id=3): 2 functions
    func_content = UInt8[0x02, 0x01, 0x01]  # 2 funcs, both type 1
    push!(bytes, 0x03)
    push!(bytes, UInt8(length(func_content)))
    append!(bytes, func_content)

    # Global section (id=6): 1 mutable i32
    global_content = UInt8[
        0x01,        # 1 global
        0x7f, 0x01,  # i32 mut
        0x41, 0x00, 0x0b,  # init: i32.const 0, end
    ]
    push!(bytes, 0x06)
    push!(bytes, UInt8(length(global_content)))
    append!(bytes, global_content)

    # Export section (id=7): 2 exports
    export_content = UInt8[
        0x02,  # 2 exports
        0x09, 0x69, 0x6e, 0x63, 0x72, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x00, 0x01,  # "increment", func 1
        0x09, 0x64, 0x65, 0x63, 0x72, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x00, 0x02,  # "decrement", func 2
    ]
    push!(bytes, 0x07)
    push!(bytes, UInt8(length(export_content)))
    append!(bytes, export_content)

    # Code section (id=10): 2 function bodies
    # increment: global.get 0, i32.const 1, i32.add, global.set 0, global.get 0, call 0, end
    inc_body = UInt8[
        0x00,        # 0 locals
        0x23, 0x00,  # global.get 0
        0x41, 0x01,  # i32.const 1
        0x6a,        # i32.add
        0x24, 0x00,  # global.set 0
        0x23, 0x00,  # global.get 0
        0x10, 0x00,  # call 0
        0x0b,        # end
    ]

    # decrement: global.get 0, i32.const 1, i32.sub, global.set 0, global.get 0, call 0, end
    dec_body = UInt8[
        0x00,        # 0 locals
        0x23, 0x00,  # global.get 0
        0x41, 0x01,  # i32.const 1
        0x6b,        # i32.sub
        0x24, 0x00,  # global.set 0
        0x23, 0x00,  # global.get 0
        0x10, 0x00,  # call 0
        0x0b,        # end
    ]

    code_content = UInt8[0x02]  # 2 functions
    push!(code_content, UInt8(length(inc_body)))
    append!(code_content, inc_body)
    push!(code_content, UInt8(length(dec_body)))
    append!(code_content, dec_body)

    push!(bytes, 0x0a)  # section id
    push!(bytes, UInt8(length(code_content)))
    append!(bytes, code_content)

    write(joinpath(DIST_DIR, "wasm", "counter.wasm"), bytes)
    println("    -> $(joinpath(DIST_DIR, "wasm", "counter.wasm")) ($(length(bytes)) bytes)")
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

    # Generate each route
    for (route_path, source_file) in ROUTES
        println("  Building: $route_path")

        # Load the component module
        source_path = joinpath(DOCS_ROOT, source_file)
        component_fn = include(source_path)

        # Generate HTML (use invokelatest to handle world age issues with dynamic include)
        route_title = if route_path == "/"
            "Therapy.jl - Reactive Web Framework for Julia"
        else
            "Therapy.jl - $(titlecase(basename(strip(route_path, '/'))))"
        end
        html = Base.invokelatest(generate_page, component_fn, title=route_title)

        # Determine output path
        if route_path == "/"
            output_path = joinpath(DIST_DIR, "index.html")
        else
            output_dir = joinpath(DIST_DIR, strip(route_path, '/'))
            mkpath(output_dir)
            output_path = joinpath(output_dir, "index.html")
        end

        # Write file
        write(output_path, html)
        println("    -> $(output_path)")
    end

    # Create wasm directory and build counter module
    mkpath(joinpath(DIST_DIR, "wasm"))
    build_counter_wasm()

    # Create a simple 404 page
    write(joinpath(DIST_DIR, "404.html"), """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - Therapy.jl</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="antialiased bg-gray-50">
    <div class="min-h-screen flex items-center justify-center">
        <div class="text-center">
            <h1 class="text-6xl font-bold text-gray-300">404</h1>
            <p class="text-xl text-gray-600 mt-4">Page not found</p>
            <a href="/" class="inline-block mt-6 px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-500 transition">
                Go Home
            </a>
        </div>
    </div>
</body>
</html>
""")

    # Create .nojekyll file for GitHub Pages (prevents Jekyll processing)
    write(joinpath(DIST_DIR, ".nojekyll"), "")

    println("\nBuild complete!")
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
