# Therapy.jl

A reactive web framework for Julia with SolidJS-inspired fine-grained reactivity.

## Features

- **Fine-grained Reactivity**: Signals, effects, and memos for precise updates
- **Pure Julia Syntax**: No macros needed - `divv()`, `button()`, `span()`
- **Component System**: Reusable components with props and children
- **Server-Side Rendering**: Generate HTML strings with hydration keys
- **Batching**: Batch multiple updates for optimal performance

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")
```

## Quick Start

```julia
using Therapy

# Create reactive signals
count, set_count = create_signal(0)

# Create a computed value
doubled = create_memo(() -> count() * 2)

# Create a side effect
create_effect() do
    println("Count: ", count(), ", Doubled: ", doubled())
end

# Update the signal - effect runs automatically
set_count(5)  # Prints: "Count: 5, Doubled: 10"
```

## Components

```julia
using Therapy

# Define a component
Counter = component(:Counter) do props
    count, set_count = create_signal(get_prop(props, :initial, 0))

    divv(:class => "counter",
        p("Count: ", count),
        button(:on_click => () -> set_count(count() - 1), "-"),
        button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML
html = render_to_string(Counter(:initial => 0))
```

## API Reference

### Reactivity

| Function | Description |
|----------|-------------|
| `create_signal(value)` | Create a reactive signal, returns `(getter, setter)` |
| `create_effect(fn)` | Create a side effect that tracks dependencies |
| `create_memo(fn)` | Create a cached computed value |
| `batch(fn)` | Batch multiple updates together |
| `dispose!(effect)` | Stop an effect from running |

### Components

| Function | Description |
|----------|-------------|
| `component(name) do props ... end` | Define a reusable component |
| `get_prop(props, key, default)` | Get a prop value |
| `get_children(props)` | Get component children |
| `render_component(instance)` | Render a component to VNode |

### DOM Elements

```julia
divv, span, p, a, button, input, form, label
h1, h2, h3, h4, h5, h6
ul, ol, li, table, tr, td, th
img, video, audio
header, footer, nav, main, section, article
textarea, select, option
# ... and more
```

### SSR

| Function | Description |
|----------|-------------|
| `render_to_string(node)` | Render VNode tree to HTML string |

### Control Flow

| Function | Description |
|----------|-------------|
| `For(items, fn)` | Iterate over items |
| `Show(condition, fn)` | Conditional rendering |
| `Fragment(children...)` | Group elements without wrapper |

## Examples

See the `examples/` directory:

```bash
julia --project=. examples/counter.jl
```

## Roadmap

- [ ] Client-side DOM rendering
- [ ] Hydration (SSR to client handoff)
- [ ] WasmTarget.jl integration (compile to WebAssembly)
- [ ] Router
- [ ] Sessions.jl (reactive notebooks)

## Related Projects

- [WasmTarget.jl](https://github.com/TherapeuticJulia/WasmTarget.jl) - Julia to WebAssembly compiler

## License

MIT
