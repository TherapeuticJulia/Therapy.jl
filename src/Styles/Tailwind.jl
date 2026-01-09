# Tailwind.jl - Tailwind CSS integration for Therapy.jl
#
# Two modes:
# 1. CDN (development) - Quick setup, no build step
# 2. CLI (production) - Optimized, only includes used classes

"""
    tailwind_cdn(; plugins=[], config=nothing)

Generate Tailwind CSS CDN script tag for development.
Uses the Play CDN which works great for development.

# Example
```julia
render_page(MyApp();
    head_extra = tailwind_cdn()
)
```
"""
function tailwind_cdn(; plugins::Vector{String}=String[], dark_mode::String="class")
    plugin_urls = join([
        "<script src=\"https://cdn.tailwindcss.com/\$(p)\"></script>"
        for p in plugins
    ], "\n    ")

    config_script = """
    <script>
        tailwind.config = {
            darkMode: '$(dark_mode)',
            theme: {
                extend: {}
            }
        }
    </script>
    """

    return """
    <script src="https://cdn.tailwindcss.com"></script>
    $(plugin_urls)
    $(config_script)
    """
end

"""
    tailwind_config(; content=["**/*.jl"], theme=Dict(), plugins=[])

Generate a tailwind.config.js content for production builds.
Write this to tailwind.config.js and run the Tailwind CLI.

# Example
```julia
config = tailwind_config(
    content = ["src/**/*.jl", "routes/**/*.jl"],
    theme = Dict("extend" => Dict("colors" => Dict("brand" => "#ff6b6b")))
)
write("tailwind.config.js", config)
# Then run: npx tailwindcss -i input.css -o output.css
```
"""
function tailwind_config(;
    content::Vector{String}=["**/*.jl"],
    theme::Dict=Dict(),
    plugins::Vector{String}=String[],
    dark_mode::String="class"
)
    content_json = "[" * join(["\"$c\"" for c in content], ", ") * "]"
    theme_json = dict_to_js(theme)
    plugins_json = "[" * join(plugins, ", ") * "]"

    return """
/** @type {import('tailwindcss').Config} */
module.exports = {
    content: $(content_json),
    darkMode: '$(dark_mode)',
    theme: $(theme_json),
    plugins: $(plugins_json),
}
"""
end

"""
Convert a Julia Dict to JavaScript object literal string.
"""
function dict_to_js(d::Dict)
    if isempty(d)
        return "{}"
    end

    parts = String[]
    for (k, v) in d
        key = string(k)
        if v isa Dict
            value = dict_to_js(v)
        elseif v isa String
            value = "\"$v\""
        elseif v isa Vector
            value = "[" * join(["\"$x\"" for x in v], ", ") * "]"
        else
            value = string(v)
        end
        push!(parts, "\"$key\": $value")
    end

    return "{\n        " * join(parts, ",\n        ") * "\n    }"
end

"""
    tw(classes...)

Helper to join Tailwind classes. Filters out empty strings and nothing.

# Example
```julia
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"),
    "Content"
)
```
"""
function tw(classes...)
    valid = filter(c -> c !== nothing && c !== "" && c !== false, classes)
    return join(string.(valid), " ")
end

# Export tw helper
export tw

"""
Base CSS for Tailwind (minimal reset).
Include this if not using the CDN.
"""
const TAILWIND_BASE_CSS = """
@tailwind base;
@tailwind components;
@tailwind utilities;
"""

"""
    tailwind_input_css()

Returns the input CSS content for Tailwind CLI.
Write this to input.css before running the Tailwind CLI.
"""
function tailwind_input_css()
    return TAILWIND_BASE_CSS
end

"""
Common Tailwind class combinations as Julia constants for convenience.
"""
module TW
    # Layout
    const FLEX_CENTER = "flex items-center justify-center"
    const FLEX_BETWEEN = "flex items-center justify-between"
    const FLEX_COL = "flex flex-col"
    const GRID_CENTER = "grid place-items-center"

    # Sizing
    const FULL = "w-full h-full"
    const SCREEN = "w-screen h-screen"

    # Spacing
    const CONTAINER = "container mx-auto px-4"

    # Buttons
    const BTN = "px-4 py-2 rounded font-medium transition-colors"
    const BTN_PRIMARY = "px-4 py-2 rounded font-medium bg-blue-500 text-white hover:bg-blue-600"
    const BTN_SECONDARY = "px-4 py-2 rounded font-medium bg-gray-200 text-gray-800 hover:bg-gray-300"
    const BTN_DANGER = "px-4 py-2 rounded font-medium bg-red-500 text-white hover:bg-red-600"

    # Inputs
    const INPUT = "px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"

    # Cards
    const CARD = "bg-white rounded-lg shadow p-6"
    const CARD_DARK = "bg-gray-800 rounded-lg shadow p-6"

    # Text
    const HEADING = "text-2xl font-bold"
    const SUBHEADING = "text-lg font-semibold text-gray-600"
    const MUTED = "text-gray-500 text-sm"
end

export TW
