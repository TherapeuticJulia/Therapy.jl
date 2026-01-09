#!/usr/bin/env julia
# Therapy.jl Documentation Site
#
# Usage:
#   julia --project=.. app.jl dev    # Development server
#   julia --project=.. app.jl build  # Build static site
#
# The docs site uses Therapy.jl's App framework - it's fully dogfooded!

# Add WasmTarget to load path
push!(LOAD_PATH, joinpath(dirname(@__DIR__), "..", "WasmTarget.jl"))

using Therapy

# =============================================================================
# Components - Reusable UI pieces
# =============================================================================

include("src/components/Layout.jl")
include("src/components/InteractiveCounter.jl")
include("src/components/ThemeToggle.jl")

# =============================================================================
# Routes - Pages of the site
# =============================================================================

include("src/routes/index.jl")
include("src/routes/getting-started.jl")

# =============================================================================
# App Configuration
# =============================================================================

app = App(
    routes = [
        "/" => Index,
        "/getting-started/" => GettingStarted,
    ],
    interactive = [
        InteractiveCounter => "#counter-demo",
        ThemeToggle => "#theme-toggle",
    ],
    title = "Therapy.jl",
    output_dir = "dist"
)

# =============================================================================
# Run - dev or build based on args
# =============================================================================

Therapy.run(app)
