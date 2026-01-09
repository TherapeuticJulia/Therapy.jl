# CLAUDE.md - Therapy.jl Development Guide

A reactive web framework for Julia with SolidJS-inspired fine-grained reactivity, SSR support, and future compilation to WasmGC.

## Project Vision

Therapy.jl aims to bring modern reactive web development to Julia with:
- **Fine-grained reactivity** (signals-based like SolidJS/Leptos, no VDOM diffing)
- **Pure Julia syntax** (function-call style: `divv()`, `button()`)
- **SSR + hydration** from day one
- **Hyper-performant** (future compilation to WasmGC via WasmTarget.jl)
- **Prepared for Sessions.jl** (reactive notebooks like Pluto)

## Architecture

```
Therapy.jl/
├── src/
│   ├── Therapy.jl              # Main module, exports API
│   ├── Reactivity/
│   │   ├── Types.jl            # Core type definitions
│   │   ├── Context.jl          # Effect stack, batch mode
│   │   ├── Effect.jl           # create_effect, dispose!
│   │   ├── Memo.jl             # create_memo
│   │   └── Signal.jl           # create_signal, batch
│   ├── DOM/
│   │   ├── VNode.jl            # VNode struct, Fragment, For, Show
│   │   ├── Elements.jl         # divv, button, span, etc.
│   │   └── Events.jl           # Event name mappings
│   ├── Components/
│   │   ├── Props.jl            # Props container
│   │   ├── Component.jl        # component(), render_component
│   │   └── Lifecycle.jl        # on_mount, on_cleanup
│   └── SSR/
│       └── Render.jl           # render_to_string
├── test/
│   └── runtests.jl             # ~60 tests
└── examples/
    └── counter.jl              # Counter demo
```

## Core API

### Signals

```julia
# Basic signal
count, set_count = create_signal(0)
count()           # => 0
set_count(5)
count()           # => 5

# Signal with transform
upper, set_upper = create_signal("hello", uppercase)
upper()  # => "HELLO"
```

### Effects

```julia
# Effects run immediately and re-run when dependencies change
create_effect() do
    println("Count is: ", count())
end

# Dispose an effect
effect = create_effect(() -> println(count()))
dispose!(effect)
```

### Memos

```julia
# Memos cache computed values
doubled = create_memo(() -> count() * 2)
doubled()  # Computed once
doubled()  # Cached, no recomputation
```

### Batching

```julia
# Batch multiple updates - effects only run once
batch() do
    set_a(1)
    set_b(2)
    set_c(3)
end
```

### Components

```julia
# Define a component
Greeting = component(:Greeting) do props
    name = get_prop(props, :name, "World")
    p("Hello, ", name, "!")
end

# Use the component
html = render_to_string(Greeting(:name => "Julia"))
```

### DOM Elements

```julia
# Function-call syntax for elements
divv(:class => "container",
    h1("Title"),
    p("Paragraph text"),
    button(:on_click => () -> println("clicked"), "Click me")
)
```

### SSR

```julia
html = render_to_string(
    divv(:class => "app",
        h1("My App"),
        Counter(:initial => 0)
    )
)
# Returns HTML string with hydration keys (data-hk attributes)
```

## Key Design Decisions

### Why function-call syntax instead of macros?
- Cleaner, more intuitive API
- Works with existing Julia tooling
- Easy to understand and debug
- Similar to React/SolidJS JSX patterns

### Why signals instead of observables?
- Simpler mental model
- Better performance (no subscription overhead)
- Fine-grained tracking (only dependent computations re-run)
- Inspired by SolidJS and Leptos success

### Why VNode instead of direct DOM?
- Enables SSR (render_to_string)
- Enables future optimizations
- Portable across runtimes (server, browser, etc.)

## Reactivity Internals

### Dependency Tracking

1. When a signal getter is called inside an effect:
   - The signal adds the effect to its subscribers
   - The effect adds the signal to its dependencies

2. When a signal setter is called:
   - All subscriber effects are notified
   - Effects re-run (or queue if batching)

3. When an effect re-runs:
   - Dependencies are cleared first
   - New dependencies are tracked during execution

### The Effect Stack

```
EFFECT_STACK: Any[]

push_effect_context!(effect)  # When effect starts
current_effect()              # Get current (for dependency tracking)
pop_effect_context!()         # When effect ends
```

## Testing

```bash
julia --project=. test/runtests.jl
```

## Examples

```bash
julia --project=. examples/counter.jl
```

## Future Work

### Near-term
- [ ] Client-side rendering (DOM manipulation)
- [ ] Hydration (connecting SSR HTML to reactivity)
- [ ] Router component
- [ ] Form handling

### Medium-term
- [ ] WasmTarget.jl integration
- [ ] Hot module reloading
- [ ] DevTools

### Long-term
- [ ] Sessions.jl (reactive notebooks)
- [ ] Full Wasm compilation
- [ ] Islands architecture

## Dependencies

Currently no external dependencies (pure Julia).

Future:
- WasmTarget.jl for Wasm compilation

## Related Projects

- **WasmTarget.jl**: Julia-to-WebAssembly compiler (foundation for client-side)
- **Sessions.jl**: Planned reactive notebook system built on Therapy.jl
