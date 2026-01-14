# Channel.jl - Discrete message passing for real-time communication
#
# Channels provide event-based communication (not continuous state).
# Use for chat messages, notifications, game events, etc.
# Messages are transient - they're delivered but not persisted.

"""
A message channel for discrete, event-based communication.

Unlike Signals which maintain continuous state, Channels:
- Pass individual messages (events)
- Don't persist state - messages are delivered once
- Can broadcast to all clients or send to specific connections
- Support bidirectional messaging (client ↔ server)

# Example
```julia
# Create a chat channel
chat = create_channel("chat")

# Handle incoming messages from clients
on_channel_message("chat") do conn, data
    # Process the message and broadcast to all
    message = Dict(
        "text" => data["text"],
        "from" => conn.id[1:8],
        "timestamp" => time()
    )
    broadcast_channel!("chat", message)
end

# Server can also send messages
broadcast_channel!("chat", Dict("text" => "Server announcement!"))
```
"""
mutable struct MessageChannel
    name::String
    handlers::Vector{Function}  # Handlers for incoming messages
end

# Registry of all channels
const MESSAGE_CHANNELS = Dict{String, MessageChannel}()

"""
    create_channel(name::String) -> Channel

Create a new message channel.

# Arguments
- `name`: Unique identifier for this channel

# Example
```julia
chat = create_channel("chat")
notifications = create_channel("notifications")
game_events = create_channel("game_events")
```
"""
function create_channel(name::String)
    if haskey(MESSAGE_CHANNELS, name)
        error("Channel '$name' already exists")
    end
    channel = MessageChannel(name, Function[])
    MESSAGE_CHANNELS[name] = channel
    return channel
end

"""
    on_channel_message(handler::Function, name::String)

Register a handler for messages on a channel.

The handler receives `(connection, data)` where:
- `connection`: The WSConnection that sent the message
- `data`: The message payload (typically a Dict)

# Example
```julia
on_channel_message("chat") do conn, data
    println("Message from \$(conn.id): \$(data["text"])")
    # Broadcast to all clients
    broadcast_channel!("chat", Dict(
        "text" => data["text"],
        "from" => conn.id
    ))
end
```
"""
function on_channel_message(handler::Function, name::String)
    if !haskey(MESSAGE_CHANNELS, name)
        @warn "Channel '$name' does not exist"
        return
    end
    push!(MESSAGE_CHANNELS[name].handlers, handler)
end

# Allow do-block syntax
function on_channel_message(name::String)
    return (handler) -> on_channel_message(handler, name)
end

"""
    handle_channel_message(conn::WSConnection, name::String, data)

Process an incoming channel message from a client.
Called internally by WebSocket message handler.
"""
function handle_channel_message(conn::WSConnection, name::String, data)
    channel = get(MESSAGE_CHANNELS, name, nothing)
    if channel === nothing
        @warn "Unknown channel" name=name
        return
    end

    for handler in channel.handlers
        try
            handler(conn, data)
        catch e
            @warn "Channel handler error" channel=name exception=e
        end
    end
end

"""
    broadcast_channel!(name::String, data)

Broadcast a message to all connected clients on a channel.

# Example
```julia
broadcast_channel!("notifications", Dict(
    "type" => "alert",
    "message" => "Server will restart in 5 minutes"
))
```
"""
function broadcast_channel!(name::String, data)
    msg = Dict(
        "type" => "channel_message",
        "channel" => name,
        "data" => data
    )
    for (_, conn) in WS_CONNECTIONS
        send_ws_message(conn, msg)
    end
end

"""
    broadcast_channel!(channel::MessageChannel, data)

Broadcast a message using a MessageChannel reference.
"""
function broadcast_channel!(channel::MessageChannel, data)
    broadcast_channel!(channel.name, data)
end

"""
    send_channel!(name::String, conn_id::String, data)

Send a message to a specific connection on a channel.

# Example
```julia
# Send private message to specific user
send_channel!("private", user_conn_id, Dict(
    "type" => "dm",
    "text" => "Hello!"
))
```
"""
function send_channel!(name::String, conn_id::String, data)
    conn = get(WS_CONNECTIONS, conn_id, nothing)
    if conn === nothing
        @warn "Connection not found" conn_id=conn_id
        return
    end
    send_ws_message(conn, Dict(
        "type" => "channel_message",
        "channel" => name,
        "data" => data
    ))
end

"""
    send_channel!(name::String, conn::WSConnection, data)

Send a message to a specific connection (by reference).
"""
function send_channel!(name::String, conn::WSConnection, data)
    send_channel!(name, conn.id, data)
end

"""
    broadcast_channel_except!(name::String, data, exclude_conn_id::String)

Broadcast to all connections EXCEPT the specified one.
Useful for echo prevention (don't send back to sender).
"""
function broadcast_channel_except!(name::String, data, exclude_conn_id::String)
    msg = Dict(
        "type" => "channel_message",
        "channel" => name,
        "data" => data
    )
    for (id, conn) in WS_CONNECTIONS
        if id != exclude_conn_id
            send_ws_message(conn, msg)
        end
    end
end

"""
    get_channel(name::String) -> Union{MessageChannel, Nothing}

Look up a channel by name.
"""
function get_channel(name::String)
    get(MESSAGE_CHANNELS, name, nothing)
end

"""
    list_channels() -> Vector{String}

Get names of all registered channels.
"""
function list_channels()
    collect(keys(MESSAGE_CHANNELS))
end

"""
    delete_channel!(name::String)

Remove a channel.
"""
function delete_channel!(name::String)
    delete!(MESSAGE_CHANNELS, name)
end

function delete_channel!(channel::MessageChannel)
    delete_channel!(channel.name)
end
