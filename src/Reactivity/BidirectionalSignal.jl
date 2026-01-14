# BidirectionalSignal.jl - Two-way reactive signals (server ↔ client)
#
# Bidirectional signals can be modified by both the server AND clients.
# Changes are synchronized across all connected clients in real-time.
# Use for collaborative features like shared documents or multiplayer state.

"""
A bidirectional signal that can be modified by both server and clients.

Unlike ServerSignals which are read-only on the client, BidirectionalSignals:
- Can be modified by any client via WebSocket
- Changes are validated by optional server-side handlers
- Updates are broadcast to all OTHER clients (not the sender)
- Use JSON patches for efficient synchronization

# Example
```julia
# Create a bidirectional signal for collaborative editing
shared_doc = create_bidirectional_signal("shared_doc", "")

# Add validation handler (optional)
on_bidirectional_update("shared_doc") do conn, new_value
    # Return false to reject, true to accept, or modified value
    if length(new_value) > 10000
        return false  # Reject too-long content
    end
    return true  # Accept
end

# Server can also update (broadcasts to all clients)
set_bidirectional_signal!(shared_doc, "Hello from server!")
```
"""
mutable struct BidirectionalSignal{T}
    name::String
    value::T
    update_handlers::Vector{Function}  # Called when client updates
end

# Registry of all bidirectional signals
const BIDIRECTIONAL_SIGNALS = Dict{String, BidirectionalSignal}()

"""
    create_bidirectional_signal(name::String, initial::T) -> BidirectionalSignal{T}

Create a new bidirectional signal that can be modified by server and clients.

# Arguments
- `name`: Unique identifier for this signal
- `initial`: Initial value of the signal

# Example
```julia
# Collaborative text editing
doc = create_bidirectional_signal("document", "")

# Shared game state
game_state = create_bidirectional_signal("game", Dict("score" => 0))
```
"""
function create_bidirectional_signal(name::String, initial::T) where T
    if haskey(BIDIRECTIONAL_SIGNALS, name)
        error("Bidirectional signal '$name' already exists")
    end
    signal = BidirectionalSignal{T}(name, initial, Function[])
    BIDIRECTIONAL_SIGNALS[name] = signal
    # Also register as a server signal so clients can subscribe
    SERVER_SIGNALS[name] = signal
    return signal
end

"""
    on_bidirectional_update(handler::Function, name::String)

Register a handler that's called when a client updates a bidirectional signal.

The handler receives `(connection, new_value)` and can:
- Return `true` to accept the update
- Return `false` to reject the update
- Return a modified value to transform the update

# Example
```julia
on_bidirectional_update("shared_doc") do conn, new_value
    # Sanitize input
    sanitized = strip(new_value)

    # Reject if empty
    if isempty(sanitized)
        return false
    end

    # Return sanitized value
    return sanitized
end
```
"""
function on_bidirectional_update(handler::Function, name::String)
    if !haskey(BIDIRECTIONAL_SIGNALS, name)
        @warn "Bidirectional signal '$name' does not exist"
        return
    end
    push!(BIDIRECTIONAL_SIGNALS[name].update_handlers, handler)
end

# Allow do-block syntax
function on_bidirectional_update(name::String)
    return (handler) -> on_bidirectional_update(handler, name)
end

"""
    handle_client_signal_update(conn::WSConnection, name::String, patch::Vector)

Process an update from a client for a bidirectional signal.
Called internally by WebSocket message handler.

This function:
1. Applies the patch to get the new value
2. Runs all validation handlers
3. Updates the signal if accepted
4. Broadcasts the change to all OTHER clients
"""
function handle_client_signal_update(conn::WSConnection, name::String, patch::Vector)
    signal = get(BIDIRECTIONAL_SIGNALS, name, nothing)
    if signal === nothing
        send_ws_error(conn, "Unknown bidirectional signal: $name")
        return
    end

    # Apply patch to get proposed new value
    new_value = apply_patch(signal.value, patch)

    # Run validation handlers
    for handler in signal.update_handlers
        try
            result = handler(conn, new_value)
            if result === false
                send_ws_error(conn, "Update rejected by server")
                return
            elseif result !== nothing && result !== true
                # Handler returned a modified value
                new_value = result
            end
        catch e
            @warn "Bidirectional update handler error" signal=name exception=e
            send_ws_error(conn, "Server error processing update")
            return
        end
    end

    # Update the signal
    old_value = signal.value
    signal.value = new_value

    # Broadcast to OTHER clients (not the sender)
    broadcast_patch = compute_patch(old_value, new_value)
    if !isempty(broadcast_patch)
        broadcast_signal_patch_except(name, broadcast_patch, conn.id)
    end

    @debug "Bidirectional signal updated" signal=name by=conn.id
end

"""
    set_bidirectional_signal!(signal::BidirectionalSignal{T}, value::T)

Update a bidirectional signal from the server side.
Broadcasts to ALL connected clients.
"""
function set_bidirectional_signal!(signal::BidirectionalSignal{T}, value::T) where T
    old_value = signal.value
    signal.value = value

    # Broadcast patch to all subscribers
    patch = compute_patch(old_value, value)
    if !isempty(patch)
        broadcast_signal_patch(signal.name, patch)
    end
end

# Allow setting with convertible types
function set_bidirectional_signal!(signal::BidirectionalSignal{T}, value) where T
    set_bidirectional_signal!(signal, convert(T, value))
end

"""
    get_bidirectional_signal(signal::BidirectionalSignal) -> T

Get the current value of a bidirectional signal.
"""
get_bidirectional_signal(signal::BidirectionalSignal) = signal.value

"""
    update_bidirectional_signal!(signal::BidirectionalSignal{T}, fn::Function)

Update a bidirectional signal by applying a function to its current value.
"""
function update_bidirectional_signal!(signal::BidirectionalSignal{T}, fn::Function) where T
    new_value = fn(signal.value)
    set_bidirectional_signal!(signal, new_value)
end

# Convenience operators
Base.getindex(signal::BidirectionalSignal) = signal.value

function Base.setindex!(signal::BidirectionalSignal{T}, value::T) where T
    set_bidirectional_signal!(signal, value)
end

function Base.setindex!(signal::BidirectionalSignal{T}, value) where T
    set_bidirectional_signal!(signal, convert(T, value))
end

"""
    get_bidirectional_signal_by_name(name::String) -> Union{BidirectionalSignal, Nothing}

Look up a bidirectional signal by name.
"""
function get_bidirectional_signal_by_name(name::String)
    get(BIDIRECTIONAL_SIGNALS, name, nothing)
end

"""
    list_bidirectional_signals() -> Vector{String}

Get names of all registered bidirectional signals.
"""
function list_bidirectional_signals()
    collect(keys(BIDIRECTIONAL_SIGNALS))
end

"""
    delete_bidirectional_signal!(name::String)

Remove a bidirectional signal.
"""
function delete_bidirectional_signal!(name::String)
    delete!(BIDIRECTIONAL_SIGNALS, name)
    delete!(SERVER_SIGNALS, name)
end

function delete_bidirectional_signal!(signal::BidirectionalSignal)
    delete_bidirectional_signal!(signal.name)
end
