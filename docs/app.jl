#!/usr/bin/env julia
# Therapy.jl Documentation Site
#
# Usage (from Therapy.jl root directory):
#   julia --project=. docs/app.jl dev    # Development server with HMR
#   julia --project=. docs/app.jl build  # Build static site to docs/dist
#
# This site dogfoods Therapy.jl's App framework with:
# - File-based routing from src/routes/
# - Automatic component loading from src/components/
# - Interactive Wasm components with HMR in dev mode

# Ensure we're using the local Therapy.jl package
# and WasmTarget.jl from the sibling directory
if !haskey(ENV, "JULIA_PROJECT")
    # Running without --project, add paths manually
    push!(LOAD_PATH, dirname(@__DIR__))  # Add Therapy.jl
end
push!(LOAD_PATH, joinpath(dirname(@__DIR__), "..", "WasmTarget.jl"))

using Therapy

# Change to docs directory for relative paths
cd(@__DIR__)

# =============================================================================
# App Configuration
# =============================================================================

app = App(
    routes_dir = "src/routes",
    components_dir = "src/components",
    interactive = [
        "InteractiveCounter" => "#counter-demo",
        "ThemeToggle" => "#theme-toggle",
    ],
    title = "Therapy.jl",
    output_dir = "dist"
)

# =============================================================================
# Run - dev or build based on args
# =============================================================================

Therapy.run(app)
