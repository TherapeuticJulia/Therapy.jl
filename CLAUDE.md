# CLAUDE.md - Therapy.jl Development Guide

A reactive web framework for Julia with SolidJS/Leptos-inspired fine-grained reactivity, SSR support, and compilation to WebAssembly.

## Quick Start

```julia
using Therapy

# Create a reactive counter
function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML
html = render_to_string(Counter())
```

## Project Structure

```
Therapy.jl/
├── src/
│   ├── Therapy.jl              # Main module, exports
│   ├── Reactivity/
│   │   ├── Types.jl            # Signal, Effect, Memo, TrackingContext
│   │   ├── Context.jl          # Effect stack, batching mode, dependency tracking
│   │   ├── Signal.jl           # create_signal, batch, handler tracing
│   │   ├── Effect.jl           # create_effect, dispose!, dependency tracking
│   │   ├── Memo.jl             # create_memo with lazy evaluation
│   │   ├── ServerSignal.jl     # Server-controlled signals (WebSocket broadcast)
│   │   ├── BidirectionalSignal.jl  # Two-way signals (client ↔ server)
│   │   └── Channel.jl          # Message channels for discrete events
│   ├── DOM/
│   │   ├── VNode.jl            # VNode, Fragment, Show, For conditionals
│   │   ├── Elements.jl         # All HTML element factory functions
│   │   └── Events.jl           # Event name mappings (30+ event types)
│   ├── Components/
│   │   ├── Component.jl        # component(), render_component
│   │   ├── Island.jl           # island(), interactive island registry
│   │   ├── Props.jl            # Props container with typed access
│   │   └── Lifecycle.jl        # on_mount, on_cleanup hooks
│   ├── SSR/
│   │   └── Render.jl           # render_to_string, render_page, hydration keys
│   ├── Router/
│   │   ├── Router.jl           # File-path routing (Next.js style)
│   │   └── ClientRouter.jl     # Client-side SPA navigation (Leptos-style)
│   ├── Styles/
│   │   └── Tailwind.jl         # Tailwind CSS integration (CDN + CLI)
│   ├── Compiler/
│   │   ├── Analysis.jl         # Component analysis, signal/handler discovery
│   │   ├── WasmGen.jl          # WebAssembly generation via WasmTarget.jl
│   │   ├── Hydration.jl        # JavaScript hydration code generation
│   │   └── Compile.jl          # compile_component main API
│   ├── Server/
│   │   ├── DevServer.jl        # Development HTTP server
│   │   ├── WebSocket.jl        # WebSocket connection handling
│   │   ├── WebSocketClient.jl  # Client-side JS generation
│   │   └── JSONPatch.jl        # RFC 6902 JSON Patch implementation
│   ├── App/
│   │   └── App.jl              # High-level app framework
│   └── SSG/
│       └── StaticSite.jl       # Static site generation
├── test/
│   └── runtests.jl             # 58 tests
├── docs/                       # Documentation site (built with Therapy.jl)
│   ├── app.jl
│   └── src/
│       ├── components/         # TicTacToe, ThemeToggle, InteractiveCounter
│       ├── routes/             # Tutorial pages
│       └── Layout.jl
└── examples/
    ├── counter.jl              # Basic SSR demo
    ├── counter_wasm.jl         # Manual Wasm compilation demo
    └── todo/
        └── app.jl              # Full reactive app with auto-compilation
```

---

## Core API

### Signals (Reactive State)

```julia
# Basic signal
count, set_count = create_signal(0)
count()           # Read: 0
set_count(5)      # Write
count()           # Read: 5

# With transform
upper, set_upper = create_signal("hello", uppercase)
upper()  # "HELLO"
```

### Effects (Side Effects)

```julia
# Runs immediately and re-runs when dependencies change
create_effect() do
    println("Count is: ", count())
end

# Cleanup
effect = create_effect(() -> println(count()))
dispose!(effect)
```

### Memos (Computed Values)

```julia
doubled = create_memo(() -> count() * 2)
doubled()  # Cached, only recomputes when count changes
```

### Batching

```julia
batch() do
    set_a(1)
    set_b(2)
    set_c(3)
end
# Effects only run once after batch
```

### DOM Elements (JSX-style)

```julia
# Capitalized like JSX/React
Div(:class => "container",
    H1("Title"),
    P("Paragraph"),
    Button(:on_click => handler, "Click me")
)

# Available elements:
# Layout: Div, Span, P, Br, Hr
# Text: H1-H6, Strong, Em, Code, Pre, Blockquote
# Lists: Ul, Ol, Li, Dl, Dt, Dd
# Tables: Table, Thead, Tbody, Tr, Th, Td
# Forms: Form, Input, Button, Textarea, Select, Option, Label
# Media: Img, Video, Audio, Iframe
# Semantic: Header, Footer, Nav, Main, Section, Article, Aside
# SVG: Svg, Path, Circle, Rect, Line, G, etc.
```

### Conditional Rendering

```julia
visible, set_visible = create_signal(true)

Show(visible) do
    Div("I'm visible!")
end
```

### List Rendering

```julia
items, set_items = create_signal(["a", "b", "c"])

For(items) do item
    Li(item)
end
```

### Components

```julia
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    P("Hello, ", name, "!")
end

# Usage
render_to_string(Greeting(:name => "Julia"))
```

### Islands (Interactive Components)

```julia
Counter = island(:Counter) do
    count, set_count = create_signal(0)

    Div(
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Islands are:
# - Auto-discovered and registered
# - Compiled to WebAssembly
# - Hydrated on the client
# - Static HTML rendered on server
```

### File-Path Routing

```
routes/
  index.jl        -> /
  about.jl        -> /about
  users/[id].jl   -> /users/:id
  posts/[...slug].jl -> /posts/*
```

```julia
router = create_router("routes"; layout=Layout)
html, route, params = handle_request(router, "/users/123")
# params[:id] == "123"
```

### Client-Side Routing (SPA)

Leptos-style client-side navigation without page reloads:

```julia
# App-level layout (persists during navigation)
app = App(
    routes_dir = "src/routes",
    layout = :Layout  # Applied at app level, not per-route
)

# Routes return just content (no Layout wrapper)
function GettingStarted()
    Div(:class => "max-w-4xl",
        H1("Getting Started"),
        P("Content here...")
    )
end

# NavLink for navigation with active states
NavLink("getting-started/", "Getting Started";
    class = "text-neutral-700",
    active_class = "text-emerald-700",
    exact = true  # Only match exact path
)
```

**How it works:**
- Full page load: Layout wraps route content (nav + main + footer)
- SPA navigation: Fetch with `X-Therapy-Partial: 1` header
- Response: Just route content (no Layout)
- Client: Swap `#page-content`, re-hydrate islands
- Result: Nav/footer persist, only content changes

**JavaScript API:**
```javascript
// Programmatic navigation
window.TherapyRouter.navigate('/new-page');

// Re-hydrate islands after dynamic content
window.TherapyRouter.hydrateIslands();

// Update active link styling
window.TherapyRouter.updateActiveLinks();
```

### WebSocket & Server Signals

Server signals enable real-time updates from server to all connected clients:

```julia
# Server-side: Create a server signal
visitors = create_server_signal("visitors", 0)

# Update it - automatically broadcasts to all subscribed clients
set_server_signal!(visitors, 42)
# or with a function
update_server_signal!(visitors, v -> v + 1)

# Lifecycle hooks
on_ws_connect() do conn
    update_server_signal!(visitors, v -> v + 1)
    println("Client connected: ", conn.id)
end

on_ws_disconnect() do conn
    update_server_signal!(visitors, v -> v - 1)
end
```

Client-side, use `data-server-signal` attribute for auto-binding:

```julia
# This element auto-updates when server broadcasts "visitors" signal
Span(:data_server_signal => "visitors", "0")

# Mark container for static hosting warning
Div(:data_ws_example => "true",
    Span(:data_server_signal => "visitors", "0")
)
```

**Features:**
- Auto-reconnect with exponential backoff
- Auto-discover `data-server-signal` elements on page load and SPA navigation
- Graceful degradation: shows warning on static hosting (GitHub Pages)
- wss:// on HTTPS, ws:// on HTTP
- JSON patches (RFC 6902) for efficient updates

### Bidirectional Signals (Collaborative)

Bidirectional signals can be modified by both server AND clients:

```julia
# Create a bidirectional signal for collaborative editing
shared_doc = create_bidirectional_signal("shared_doc", "")

# Add validation handler (optional)
on_bidirectional_update("shared_doc") do conn, new_value
    if length(new_value) > 50000
        return false  # Reject updates over 50KB
    end
    return true  # Accept
end

# Server can also update (broadcasts to all clients)
set_bidirectional_signal!(shared_doc, "Hello from server!")
```

Client-side with `data-bidirectional-signal`:

```julia
# Textarea that syncs with server and other clients
Textarea(
    :data_bidirectional_signal => "shared_doc",
    :oninput => "TherapyWS.setBidirectional('shared_doc', this.value)"
)
```

Changes sync using JSON patches (RFC 6902) - only diffs are sent, not full values.

### Message Channels (Chat)

Channels are for discrete messages (events), not continuous state:

```julia
# Create a chat channel
chat = create_channel("chat")

# Handle incoming messages from clients
on_channel_message("chat") do conn, data
    message = Dict(
        "text" => data["text"],
        "from" => conn.id[1:8],
        "timestamp" => time()
    )
    broadcast_channel!("chat", message)
end

# Server can also send messages
broadcast_channel!("chat", Dict("text" => "Server announcement!"))

# Send to specific connection
send_channel!("private", conn_id, Dict("text" => "Hello!"))

# Broadcast except sender (avoid echo)
broadcast_channel_except!("chat", message, sender_conn_id)
```

Client-side listening:

```javascript
// Send a message
TherapyWS.sendMessage('chat', { text: 'Hello!' });

// Listen for messages
TherapyWS.onChannelMessage('chat', function(data) {
    console.log('Message:', data.text, 'from', data.from);
});

// Or use DOM events
window.addEventListener('therapy:channel:chat', function(e) {
    console.log('Message:', e.detail);
});
```

### WebSocket JavaScript API

```javascript
// Connection status
TherapyWS.isConnected()
TherapyWS.getConnectionId()

// Server signals (read-only)
TherapyWS.subscribe("signal_name")
TherapyWS.unsubscribe("signal_name")
TherapyWS.discoverAndSubscribe()  // Auto-scan DOM

// Bidirectional signals
TherapyWS.setBidirectional("signal_name", newValue)
TherapyWS.getSignalValue("signal_name")

// Channel messaging
TherapyWS.sendMessage("channel_name", { data: "here" })
TherapyWS.onChannelMessage("channel_name", callback)

// Events
window.addEventListener('therapy:ws:connected', () => { ... })
window.addEventListener('therapy:ws:disconnected', () => { ... })
window.addEventListener('therapy:signal:visitors', (e) => {
    console.log('New value:', e.detail.value)
})
window.addEventListener('therapy:channel:chat', (e) => {
    console.log('Message:', e.detail)
})
```

### Tailwind CSS

```julia
# Development (CDN)
render_page(App(); head_extra=tailwind_cdn())

# Production config
write("tailwind.config.js", tailwind_config(
    content = ["src/**/*.jl", "routes/**/*.jl"]
))

# Class helper
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"))
```

### SSR

```julia
# Simple
html = render_to_string(Div("Hello"))

# Full page
html = render_page(App();
    title = "My App",
    head_extra = tailwind_cdn()
)
```

---

## Running Tests

```bash
julia --project=. test/runtests.jl
```

## Running Examples

```bash
# Basic SSR demo
julia --project=. examples/counter.jl

# Manual Wasm compilation demo
julia --project=. examples/counter_wasm.jl

# Full reactive app (compile_component + serve)
cd examples/todo && julia --project=../.. app.jl
# Then open http://127.0.0.1:8080

# Documentation site
cd docs && julia --project=.. app.jl dev
```

---

## Architecture Overview

### Fine-Grained Reactivity

Unlike React's VDOM diffing, Therapy.jl tracks signal dependencies precisely. When a signal changes, only the specific DOM nodes that depend on it are updated. This is the same model as SolidJS and Leptos.

**Reactive Graph:**
```
Signals (root nodes)
    ↓ read by
Memos (derived/cached)
    ↓ read by
Effects (leaf nodes / side effects)
```

### Islands Architecture

Therapy.jl follows Leptos's islands pattern: **static by default, opt-in interactivity**.

- Static components render to HTML only (no JavaScript)
- Interactive `island()` components compile to WebAssembly and hydrate on the client
- Islands are auto-discovered and auto-hydrated via `data-hk` attributes

### VNode is Compile-Time Only

VNodes are used for SSR and analysis, not runtime diffing. At runtime, Wasm directly updates DOM nodes by hydration key (`data-hk`).

### Direct IR Compilation

Event handlers are compiled directly from Julia IR to WebAssembly:

1. `compile_component()` analyzes the component to find signals and handlers
2. Handler closures are inspected via `Base.code_typed()` to get their IR
3. Signal getters/setters in closures are substituted with Wasm `global.get`/`global.set`
4. DOM update calls are automatically injected after signal writes
5. Type conversions (e.g., Int64 to f64) are handled automatically

This enables compiling **arbitrary Julia code** to Wasm, not just simple patterns.

### Compilation Pipeline

```
Island Component
    ↓
Analysis Phase (src/Compiler/Analysis.jl)
├─ Execute component in analysis mode
├─ Discover all signals created
├─ Extract handler closures
├─ Build DOM structure with hydration keys
    ↓
WasmGen Phase (src/Compiler/WasmGen.jl)
├─ Create Wasm globals for each signal
├─ Compile handler IR to Wasm bytecode
├─ Inject DOM update calls (update_text, set_visible)
├─ Use WasmTarget.jl for binary generation
    ↓
Hydration Phase (src/Compiler/Hydration.jl)
├─ Generate JavaScript to load Wasm module
├─ Connect event listeners to exported handlers
├─ Set up input bindings
    ↓
Output: HTML + Wasm binary + Hydration JS
```

### f64 DOM Values

All numeric values passed to DOM imports use f64 (JavaScript's number type). Type conversion is handled automatically by WasmTarget.jl, so users can write regular Julia code with `Int`, `Int32`, `Float64`, etc.

---

## TherapeuticJulia Ecosystem

Therapy.jl is part of the TherapeuticJulia organization:

- **Therapy.jl** - Reactive web framework (this project)
- **WasmTarget.jl** - Julia-to-WebAssembly compiler (foundation)
- **Sessions.jl** - Persistent coding sessions (future)

### WasmTarget.jl Integration

Therapy.jl depends on WasmTarget.jl for Wasm compilation. The separation of concerns is intentional:

**WasmTarget.jl handles (generic Wasm compiler):**
- `compile_closure_body()` - IR extraction and WasmGC code generation
- Type registry, function registry, SSA analysis
- Control flow compilation (loops, branches, phis)
- All intrinsic mappings (arithmetic, comparisons, etc.)
- 305+ passing tests, structs, arrays, strings, closures, exceptions

**Therapy.jl handles (web framework concerns only):**
- DOM-specific imports (`dom.update_text`, `dom.set_visible`, `dom.set_dark_mode`)
- Mapping reactive signals → Wasm globals
- `dom_bindings` specification - tells WasmTarget.jl what DOM calls to inject after signal writes
- Thin wrappers for signal getters/setters and input handlers

**Key integration pattern:**
```julia
# Therapy.jl builds the DOM bindings specification
dom_bindings = Dict{UInt32, Vector{Tuple{UInt32, Vector{Int32}}}}()
# Maps: global_idx -> [(import_idx, const_args), ...]
# Example: signal global 0 -> [(0, [42])] means "after writing global 0, call import 0 with arg 42"

# Then delegates compilation to WasmTarget.jl
body, locals = compile_closure_body(
    handler_closure,
    captured_signal_fields,  # Maps closure fields to Wasm globals
    mod,
    type_registry;
    dom_bindings = dom_bindings,  # WasmTarget injects these calls automatically
    void_return = true
)
```

This design means Therapy.jl never touches Wasm opcodes for business logic - it only specifies *what* DOM side effects to inject, and WasmTarget.jl handles *how* to compile and inject them.

---

## Leptos Feature Parity Analysis

Therapy.jl aims for feature parity with Leptos.rs. Current status:

### Implemented (Core Complete)

| Feature | Status | Notes |
|---------|--------|-------|
| Signals (getter/setter) | ✅ Done | `create_signal()` |
| Effects | ✅ Done | `create_effect()` |
| Memos | ✅ Done | `create_memo()` |
| Batching | ✅ Done | `batch()` |
| Components | ✅ Done | `component()` |
| Props with defaults | ✅ Done | `get_prop()` |
| Children slot | ✅ Done | `get_children()` |
| Show conditional | ✅ Done | `Show()` |
| For list rendering | ✅ Done | `For()` |
| SSR | ✅ Done | `render_to_string()` |
| Hydration keys | ✅ Done | `data-hk` attributes |
| Islands architecture | ✅ Done | `island()` |
| File-based routing | ✅ Done | `[id].jl`, `[...slug].jl` |
| Wasm compilation | ✅ Done | Via WasmTarget.jl |
| Two-way input binding | ✅ Done | Auto-generated handlers |
| Theme binding | ✅ Done | Dark mode toggle |

### Gaps (Roadmap)

| Feature | Leptos | Therapy.jl | Priority |
|---------|--------|------------|----------|
| **Async & Data** | | | |
| Resource (async data) | ✅ | ❌ | **P1** |
| Suspense boundaries | ✅ | ❌ | **P1** |
| Transition | ✅ | ❌ | P2 |
| **Server Integration** | | | |
| Server functions (@server RPC) | ✅ | ❌ | **P1** |
| ActionForm (progressive) | ✅ | ❌ | P2 |
| Serialization server↔client | ✅ | ❌ | **P1** |
| **WebSocket & Real-Time** | | | |
| WebSocket connection | ✅ `provide_websocket()` | ✅ `websocket_client_script()` | Done |
| Server signals (read-only client) | ✅ `leptos_server_signal` | ✅ `create_server_signal()` | Done |
| Auto-reconnect | ✅ | ✅ Exponential backoff | Done |
| Auto-discover DOM bindings | ❌ Manual | ✅ `data-server-signal` attr | **Ahead!** |
| Static hosting graceful degradation | ❌ | ✅ Warning UI | **Ahead!** |
| JSON patch sync | ✅ | ✅ RFC 6902 | Done |
| Bidirectional signals | ✅ `leptos_ws` | ✅ `create_bidirectional_signal()` | Done |
| Channel signals (messaging) | ✅ `ChannelSignal` | ✅ `create_channel()` | Done |
| Server function streaming | ⚠️ PR #3656 | ❌ | P3 |
| **Router** | | | |
| Client-side navigation | ✅ | ✅ | Done |
| Nested routes + Outlet | ✅ | ❌ | P2 |
| use_params() / use_query() | ✅ | ❌ | **P1** |
| **Context** | | | |
| provide_context/use_context | ✅ | ❌ | **P1** |
| **View** | | | |
| Dynamic classes/styles | ✅ | ⚠️ Partial | P2 |
| ErrorBoundary | ✅ | ❌ | P2 |
| Portal | ✅ | ❌ | P3 |
| **SSR Advanced** | | | |
| Streaming SSR | ✅ | ❌ | P2 |
| Out-of-order streaming | ✅ | ❌ | P3 |
| **Optimization** | | | |
| Code splitting (@lazy) | ✅ | ❌ | P3 |

---

## Leptos WebSocket Architecture (Parity Target)

Leptos has **three layers** of WebSocket support that we need to match:

### 1. leptos_server_signal (Server → Client)

Server-controlled signals that are **read-only on the client**. Changes sent as **JSON patches** (efficient diffs).

**Use cases:** Real-time dashboards, live data feeds, notifications, multiplayer game state

```rust
// Leptos (Rust)
// Server side
let signal = ServerSignal::new(initial_value);
signal.with(|s| *s = new_value); // Broadcasts to all clients

// Client side (read-only)
let value = create_server_signal::<MyType>();
```

**Therapy.jl equivalent needed:**
```julia
# Server side
count = create_server_signal(0)
set_server_signal!(count, 5)  # Broadcasts via WebSocket

# Client side (read-only, auto-synced)
# Signal updates automatically when server pushes
```

### 2. leptos_ws (Bidirectional)

Three signal types for different communication patterns:

| Type | Direction | Use Case |
|------|-----------|----------|
| `ReadOnlySignal` | Server → Client | Live data, notifications |
| `BiDirectionalSignal` | Server ↔ Client | Collaborative editing, shared state |
| `ChannelSignal` | Messages both ways | Chat, discrete events |

**Key feature:** All use JSON patches for efficient sync (only send diffs, not full state).

### 3. Server Function WebSocket Transport (PR #3656)

Extends `#[server]` functions to work over WebSocket with **streaming** support:
- Accept streams of items from client
- Emit streams of items to client
- Same API as HTTP server functions, different transport

---

## WebSocket Implementation Plan for Therapy.jl

### Phase 2.5: WebSocket Infrastructure (NEW - High Priority)

**Goal:** Real-time server-client communication matching Leptos capabilities

#### Step 1: WebSocket Connection Layer

```julia
# Server-side: WebSocket endpoint using HTTP.jl
function ws_endpoint(ws::HTTP.WebSocket)
    # Register connection
    connection_id = register_ws_connection(ws)

    try
        while !eof(ws)
            msg = String(readavailable(ws))
            handle_ws_message(connection_id, JSON.parse(msg))
        end
    finally
        unregister_ws_connection(connection_id)
    end
end

# Client-side (in hydration JS):
function provide_websocket(url) {
    const ws = new WebSocket(url);
    ws.onmessage = (e) => handleServerMessage(JSON.parse(e.data));
    // Auto-reconnect logic
    return ws;
}
```

**Files:** `src/Server/WebSocket.jl`, `src/Compiler/Hydration.jl`

#### Step 2: Server Signals (Read-Only Client)

```julia
# Create a server-controlled signal
visitors = create_server_signal(Int32(0))

# Server can update - broadcasts to all connected clients
function on_new_visitor()
    update_server_signal!(visitors, visitors[] + 1)
end

# In component (client reads, can't write)
Div("Current visitors: ", visitors)
```

**Implementation:**
- Server maintains signal registry with current values
- On update, compute JSON patch and broadcast to all connections
- Client hydration JS receives patches and updates local signal copy
- Wasm globals updated via `set_signal_X()` exports

**Files:** `src/Reactivity/ServerSignal.jl`, `src/Server/SignalBroadcast.jl`

#### Step 3: Bidirectional Signals

```julia
# Shared state - both server and client can modify
shared_doc = create_shared_signal(DocumentState())

# Client modification (via Wasm handler)
:on_input => (text) -> update_shared!(shared_doc, text)

# Server modification (e.g., from another client or server logic)
update_shared!(shared_doc, validated_text)
```

**Implementation:**
- Client changes send patches to server via WebSocket
- Server validates, applies, and rebroadcasts to other clients
- Conflict resolution: last-write-wins or custom merge function
- Optimistic updates on client (rollback if server rejects)

**Files:** `src/Reactivity/SharedSignal.jl`

#### Step 4: Channel Signals (Messaging)

```julia
# Create a typed message channel
chat = create_channel(ChatMessage)

# Send from client (in Wasm handler)
:on_click => () -> send!(chat, ChatMessage(user_id, text()))

# Receive on client (reactive)
For(messages(chat)) do msg
    ChatBubble(msg)
end

# Server can also send
broadcast!(chat, SystemMessage("User joined"))
```

**Files:** `src/Reactivity/Channel.jl`

#### Step 5: JSON Patch Protocol

Efficient sync using RFC 6902 JSON Patches:

```julia
# Instead of sending full state:
# { "users": [...100 users...] }

# Send only the diff:
# [{"op": "add", "path": "/users/-", "value": {"name": "New User"}}]

using JSONPatch  # Or implement minimal version

function compute_patch(old_state, new_state)
    # Returns array of patch operations
end

function apply_patch(state, patch)
    # Applies patch operations to state
end
```

**Files:** `src/Server/JSONPatch.jl`

### WebSocket Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Server (Julia)                        │
├─────────────────────────────────────────────────────────────┤
│  SignalRegistry          ChannelRegistry                     │
│  ┌──────────────┐       ┌──────────────┐                    │
│  │ visitors: 42 │       │ chat: [...]  │                    │
│  │ doc: {...}   │       │ events: [...]│                    │
│  └──────────────┘       └──────────────┘                    │
│         │                      │                             │
│         ▼                      ▼                             │
│  ┌─────────────────────────────────────┐                    │
│  │     WebSocket Connection Manager     │                    │
│  │  - Connection registry               │                    │
│  │  - JSON patch computation            │                    │
│  │  - Broadcast to subscribers          │                    │
│  └─────────────────────────────────────┘                    │
│                    │                                         │
└────────────────────┼─────────────────────────────────────────┘
                     │ WebSocket (JSON patches)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      Client (Browser)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐                    │
│  │         Hydration JS Layer           │                    │
│  │  - WebSocket connection              │                    │
│  │  - Patch application                 │                    │
│  │  - Signal sync to Wasm               │                    │
│  └─────────────────────────────────────┘                    │
│                    │                                         │
│                    ▼                                         │
│  ┌─────────────────────────────────────┐                    │
│  │           Wasm Module                │                    │
│  │  ┌─────────────┐ ┌─────────────┐    │                    │
│  │  │ signal_0: 42│ │ handlers    │    │                    │
│  │  │ signal_1:...│ │ (compiled)  │    │                    │
│  │  └─────────────┘ └─────────────┘    │                    │
│  └─────────────────────────────────────┘                    │
│                    │                                         │
│                    ▼                                         │
│              DOM Updates                                     │
└─────────────────────────────────────────────────────────────┘
```

### Priority Order

1. **WebSocket connection + auto-reconnect** - Foundation
2. **Server signals (read-only)** - Most common use case
3. **JSON patch protocol** - Efficiency for all signal types
4. **Bidirectional signals** - Collaborative features
5. **Channel signals** - Messaging patterns
6. **Server function streaming** - Advanced use cases

---

## Implementation Roadmap

### Phase 1: Context & Reactivity Completion

**Goal:** Complete reactive foundation

1. **Context API**
   - `provide_context(key, value)` - Provide value to descendants
   - `use_context(key)` - Access context value
   - Thread context through component tree
   - Files: `src/Reactivity/Context.jl`, `src/Components/Component.jl`

2. **Trigger Primitive**
   - Signalless reactivity for pure notification
   - Files: `src/Reactivity/Trigger.jl`

3. **WasmTarget Control Flow Fixes**
   - Fix nested conditionals in void handlers
   - Enable full TicTacToe winner detection

### Phase 2: Async & Data Fetching

**Goal:** Enable async data loading patterns

1. **Resource Type**
   ```julia
   user = create_resource(
       () -> user_id(),           # Source signal
       (id) -> fetch_user(id)     # Async fetcher
   )
   ```
   - States: loading, error, data
   - Reactive dependency tracking
   - Files: `src/Reactivity/Resource.jl`

2. **Suspense Component**
   ```julia
   Suspense(
       fallback = () -> P("Loading..."),
       children = () -> UserProfile(user = user())
   )
   ```
   - Renders fallback while resources loading
   - Files: `src/Components/Suspense.jl`

3. **Transition Component**
   - Keep current content visible during loading
   - Files: `src/Components/Transition.jl`

### Phase 3: Server Functions

**Goal:** Seamless server-client communication

1. **@server Macro**
   ```julia
   @server function get_user(id::Int)::User
       DB.query("SELECT * FROM users WHERE id = ?", id)
   end
   ```
   - Server-side: Function registration and execution
   - Client-side: HTTP stub generation
   - Files: `src/Server/ServerFunctions.jl`

2. **Serialization Protocol**
   - JSON or MessagePack
   - Type-safe serialization/deserialization
   - Files: `src/Server/Serialization.jl`

3. **ActionForm Component**
   ```julia
   ActionForm(
       action = create_user,
       children = () -> [Input(:name => "email"), Button("Submit")]
   )
   ```
   - Works without JS (progressive enhancement)
   - Files: `src/Components/ActionForm.jl`

### Phase 4: Client-Side Router ✅ COMPLETE

**Goal:** SPA-style navigation without full page reloads

1. **History API Integration** ✅
   - Intercept link clicks (all internal `<a>` tags)
   - Push/pop state handling (back/forward buttons)
   - Partial page fetching with `X-Therapy-Partial: 1` header
   - Layout persists, only `#page-content` swaps
   - Files: `src/Router/ClientRouter.jl`

2. **NavLink Component** ✅
   ```julia
   NavLink("getting-started/", "Getting Started";
       class = "nav-link",
       active_class = "text-emerald-700"
   )
   ```
   - Client-side navigation with active state
   - `data-navlink` attribute for router detection
   - `data-exact` for exact path matching
   - Files: `src/Router/Router.jl`

3. **App-Level Layout** ✅
   ```julia
   app = App(
       routes_dir = "src/routes",
       layout = :Layout  # Symbol for deferred resolution
   )
   ```
   - Layout applied at app level (not per-route)
   - Routes return just content, not wrapped in Layout
   - Enables true SPA with persistent nav/footer

4. **Reactive Route Primitives** (TODO)
   ```julia
   params = use_params()      # Reactive route params
   query = use_query()        # Reactive query string
   ```
   - Files: `src/Router/Hooks.jl`

5. **Nested Routes & Outlet** (TODO)
   ```julia
   Route("/users", UserLayout,
       Route("/:id", UserDetail)
   )
   # UserLayout contains <Outlet/> for child routes
   ```
   - Files: `src/Router/Outlet.jl`

### Phase 5: Production Readiness

**Goal:** Production-grade features

1. **Streaming SSR**
   - Yield HTML chunks as data resolves
   - Placeholder markers for Suspense
   - Inline scripts for content swapping
   - Files: `src/SSR/Streaming.jl`

2. **Error Boundaries**
   ```julia
   ErrorBoundary(
       fallback = (err) -> P("Error: ", err.message),
       children = () -> RiskyComponent()
   )
   ```
   - Files: `src/Components/ErrorBoundary.jl`

3. **Code Splitting**
   ```julia
   @lazy InteractiveChart  # Load only when needed
   ```
   - Files: `src/Compiler/CodeSplitting.jl`

4. **Dynamic Classes & Styles**
   ```julia
   Div(
       :class => () -> count() > 5 ? "text-red-500" : "text-green-500",
       :style => () -> Dict("transform" => "rotate($(angle())deg)")
   )
   ```
   - Compile reactive class/style to Wasm
   - Files: `src/Compiler/DynamicStyles.jl`

---

## Known Limitations

### WasmTarget.jl Constraints

1. **Complex Control Flow in Void Handlers**
   - TicTacToe winner checking has edge cases
   - Nested conditionals in void-returning functions
   - Workaround: Return dummy value or restructure logic

2. **Array Resize**
   - WasmGC arrays have fixed size at creation
   - `push!`, `pop!` cannot be compiled
   - Workaround: Pre-allocate or use SimpleDict

3. **String Indexing**
   - UTF-8 complexity in Julia IR
   - Use character iteration instead

4. **Math Functions**
   - `sin()`, `cos()` compile but may have value errors
   - Use lookup tables for critical precision

### Therapy.jl Constraints

1. **No Async Data Handling**
   - No Resource/Suspense yet
   - Roadmap Phase 2

2. **No Server Functions**
   - Manual fetch() calls required
   - Roadmap Phase 3

---

## Architectural Advantages

### WasmGC-First Approach

Unlike Leptos (linear memory + manual management), Therapy.jl uses WasmGC:

- **Automatic GC** - No manual memory management
- **Simpler structs/arrays** - Direct mapping to WasmGC types
- **Better browser integration** - WasmGC now stable in all major browsers
- **Smaller binaries** - No runtime overhead for memory management

### Julia's Type System

- Full type inference via `Base.code_typed()`
- No runtime type checks in compiled Wasm
- Seamless f64 conversion for DOM values

### Direct IR Compilation

- No interpretation or tracing
- Clean typed IR → Wasm bytecode
- Arbitrary Julia code compiles (not just patterns)

---

## Development Workflow

```bash
# Development with hot reload (planned)
julia app.jl dev

# Build static site
julia app.jl build

# Output to dist/ (GitHub Pages ready)
```

### Testing Wasm Compilation

```julia
using Therapy

# Define island
Counter = island(:Counter) do
    count, set_count = create_signal(0)
    Div(
        Button(:on_click => () -> set_count(count() + 1), "+"),
        Span(count)
    )
end

# Compile
html, wasm_bytes, hydration_js = compile_component(Counter)

# Inspect
println("HTML: ", html)
println("Wasm size: ", length(wasm_bytes), " bytes")
println("JS: ", hydration_js)
```

---

## Dependencies

- **WasmTarget.jl** - Julia-to-WebAssembly compiler (local path)
- **HTTP.jl** - Dev server and request handling
- **Sockets.jl** - Network utilities

Minimal dependencies by design.

---

## Contributing

### Key Files to Read First

1. `src/Reactivity/Signal.jl` - Core reactive primitive
2. `src/Components/Island.jl` - Interactive component definition
3. `src/Compiler/Compile.jl` - Main compilation pipeline
4. `src/SSR/Render.jl` - Server-side rendering

### Adding a New Feature

1. Check roadmap priority
2. Write tests first (`test/runtests.jl`)
3. Implement in appropriate module
4. Update this CLAUDE.md
5. Add example if user-facing

### Code Style

- Julia conventions (4-space indent)
- Descriptive function names
- Document public API with docstrings
- Keep modules focused and small
