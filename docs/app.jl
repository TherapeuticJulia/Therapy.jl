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
# and WasmTarget.jl from the sibling directory (for local dev)
if !haskey(ENV, "JULIA_PROJECT")
    # Running without --project, add paths manually
    push!(LOAD_PATH, dirname(@__DIR__))  # Add Therapy.jl
end

# Use local WasmTarget.jl if available (for development)
# Otherwise it's loaded from Project.toml [sources] (for CI)
local_wasmtarget = joinpath(dirname(@__DIR__), "..", "WasmTarget.jl")
if isdir(local_wasmtarget)
    push!(LOAD_PATH, local_wasmtarget)
end

using Therapy

# Change to docs directory for relative paths
cd(@__DIR__)

# =============================================================================
# App Configuration
# =============================================================================

# Islands are auto-discovered from component files that use island()
# No need to manually list interactive components anymore!
#
# The Layout is applied at the app level for true SPA navigation.
# Routes return just their page content (not wrapped in Layout).
app = App(
    routes_dir = "src/routes",
    components_dir = "src/components",
    title = "Therapy.jl",
    output_dir = "dist",
    # Base path for GitHub Pages (https://therapeuticjulia.github.io/Therapy.jl/)
    base_path = "/Therapy.jl",
    # Layout applied at app level - routes return just their content
    # Use Symbol for deferred resolution (Layout loaded after components)
    layout = :Layout
)

# =============================================================================
# WebSocket Server Signals
# =============================================================================

# Create a server signal for live visitor count
# This broadcasts to all connected WebSocket clients when updated
visitors = create_server_signal("visitors", 0)

# Track connections with lifecycle hooks
on_ws_connect() do conn
    # Increment visitor count - automatically broadcasts to all clients
    update_server_signal!(visitors, v -> v + 1)
    println("[WS] Client connected: $(conn.id) ($(visitors[]) visitors)")
end

on_ws_disconnect() do conn
    # Decrement on disconnect
    update_server_signal!(visitors, v -> max(0, v - 1))
    println("[WS] Client disconnected: $(conn.id) ($(visitors[]) visitors)")
end

# =============================================================================
# Run - dev or build based on args
# =============================================================================

Therapy.run(app)
