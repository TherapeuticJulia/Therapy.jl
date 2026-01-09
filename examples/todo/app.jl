# Todo App Example - Demonstrates Therapy.jl features
#
# Run with: julia --project=../.. app.jl
# Then open: http://localhost:8080

using Therapy

# ============================================================================
# Layout - Wraps all pages
# ============================================================================

function Layout(content, params)
    Div(:class => "min-h-screen bg-gray-100",
        # Header
        Header(:class => "bg-white shadow",
            Div(:class => "max-w-4xl mx-auto px-4 py-4",
                Div(:class => "flex items-center justify-between",
                    H1(:class => "text-xl font-bold text-gray-900", "Therapy.jl Todo"),
                    Nav(:class => "flex gap-4",
                        NavLink("/", "Home"; class="text-gray-600 hover:text-gray-900"),
                        NavLink("/about", "About"; class="text-gray-600 hover:text-gray-900")
                    )
                )
            )
        ),
        # Main content
        Main(:class => "max-w-4xl mx-auto px-4 py-8",
            Div(:id => "app", content)
        ),
        # Router script for client-side navigation
        router_script()
    )
end

# ============================================================================
# Create Router
# ============================================================================

router = create_router(joinpath(@__DIR__, "routes"); layout=Layout)
print_routes(router)

# ============================================================================
# Start Server
# ============================================================================

function main()
    println("\n🚀 Starting Todo App...")
    println("   http://localhost:8080\n")

    serve(8080) do request
        path = get(request, :path, "/")
        is_partial = get(request, :headers, Dict())["X-Therapy-Partial"] == "1" rescue false

        html, route, params = handle_request(router, path)

        if is_partial
            # Just return the content without layout for client-side nav
            return html
        end

        # Full page with Tailwind
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Todo App - Therapy.jl</title>
            $(tailwind_cdn())
        </head>
        <body>
            $(html)
        </body>
        </html>
        """
    end
end

main()
