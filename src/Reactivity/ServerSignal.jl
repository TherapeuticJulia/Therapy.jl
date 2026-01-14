# ServerSignal.jl - Server-controlled signals that broadcast to WebSocket clients
#
# Server signals are read-only on the client. When the server updates them,
# all subscribed WebSocket clients receive the new value automatically.

"""
A server-controlled signal that broadcasts updates to WebSocket clients.

Unlike regular signals which are client-side only, ServerSignals:
- Are created and managed on the server
- Can only be modified by server code
- Automatically broadcast to all subscribed WebSocket clients
- Are read-only on the client side

# Example
```julia
# Create a server signal
visitors = create_server_signal("visitors", 0)

# Update it (broadcasts to all subscribers)
set_server_signal!(visitors, visitors[] + 1)

# Get current value
current = get_server_signal(visitors)
# or
current = visitors[]
```
"""
mutable struct ServerSignal{T}
    name::String
    value::T
end

# Note: SERVER_SIGNALS and broadcast_signal_update are defined in WebSocket.jl
# which is included before this file in Therapy.jl

"""
    create_server_signal(name::String, initial::T) -> ServerSignal{T}

Create a new server signal with the given name and initial value.
The name must be unique across all server signals.

# Arguments
- `name`: Unique identifier for this signal (used by clients to subscribe)
- `initial`: Initial value of the signal

# Example
```julia
counter = create_server_signal("visitor_count", 0)
messages = create_server_signal("chat_messages", String[])
```
"""
function create_server_signal(name::String, initial::T) where T
    if haskey(SERVER_SIGNALS, name)
        error("Server signal '$name' already exists")
    end
    signal = ServerSignal{T}(name, initial)
    SERVER_SIGNALS[name] = signal
    return signal
end

"""
    set_server_signal!(signal::ServerSignal{T}, value::T)

Update a server signal's value and broadcast to all subscribed clients.

# Example
```julia
visitors = create_server_signal("visitors", 0)
set_server_signal!(visitors, 42)  # All subscribers receive {"type": "signal_update", "signal": "visitors", "value": 42}
```
"""
function set_server_signal!(signal::ServerSignal{T}, value::T) where T
    signal.value = value
    broadcast_signal_update(signal.name, value)
end

# Also allow setting with different but convertible types
function set_server_signal!(signal::ServerSignal{T}, value) where T
    signal.value = convert(T, value)
    broadcast_signal_update(signal.name, signal.value)
end

"""
    get_server_signal(signal::ServerSignal) -> T

Get the current value of a server signal.
"""
get_server_signal(signal::ServerSignal) = signal.value

"""
    update_server_signal!(signal::ServerSignal{T}, fn::Function)

Update a server signal by applying a function to its current value.
Broadcasts the new value to all subscribers.

# Example
```julia
counter = create_server_signal("counter", 0)
update_server_signal!(counter, x -> x + 1)  # Increment
```
"""
function update_server_signal!(signal::ServerSignal{T}, fn::Function) where T
    new_value = fn(signal.value)
    set_server_signal!(signal, new_value)
end

# Convenience: allow signal[] syntax for getting value
Base.getindex(signal::ServerSignal) = signal.value

# Convenience: allow signal[] = value syntax for setting
function Base.setindex!(signal::ServerSignal{T}, value::T) where T
    set_server_signal!(signal, value)
end

function Base.setindex!(signal::ServerSignal{T}, value) where T
    set_server_signal!(signal, convert(T, value))
end

"""
    get_server_signal_by_name(name::String) -> Union{ServerSignal, Nothing}

Look up a server signal by its name.
Returns nothing if no signal with that name exists.
"""
function get_server_signal_by_name(name::String)
    get(SERVER_SIGNALS, name, nothing)
end

"""
    list_server_signals() -> Vector{String}

Get a list of all registered server signal names.
"""
function list_server_signals()
    collect(keys(SERVER_SIGNALS))
end

"""
    delete_server_signal!(name::String)

Remove a server signal. Subscribed clients will no longer receive updates.
"""
function delete_server_signal!(name::String)
    delete!(SERVER_SIGNALS, name)
end

"""
    delete_server_signal!(signal::ServerSignal)

Remove a server signal by reference.
"""
function delete_server_signal!(signal::ServerSignal)
    delete!(SERVER_SIGNALS, signal.name)
end
