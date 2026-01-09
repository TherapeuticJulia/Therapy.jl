# Therapy.jl

A reactive web framework for Julia inspired by [Leptos](https://leptos.dev) and [SolidJS](https://solidjs.com).

## Features

- **Fine-grained Reactivity** - Signals, effects, and memos for precise DOM updates (no virtual DOM diffing)
- **JSX-style Elements** - Capitalized elements like React: `Div`, `Button`, `Span`
- **File-path Routing** - Next.js-style routing with dynamic params
- **Tailwind CSS** - Built-in integration (CDN for dev, CLI for production)
- **SSR + Hydration** - Server-side rendering with WebAssembly hydration
- **Wasm Compilation** - Event handlers compile to WebAssembly via WasmTarget.jl

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")
```

## Quick Start

Create `app.jl`:

```julia
using Therapy

function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex items-center gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl font-bold", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

app = App(
    routes_dir = "routes",
    interactive = ["Counter" => "#counter"]
)

Therapy.run(app)
```

Run with:
```bash
julia --project=. app.jl dev    # Development server with HMR
julia --project=. app.jl build  # Build static site
```

## File-Path Routing

```
routes/
  index.jl          -> /
  about.jl          -> /about
  users/[id].jl     -> /users/:id
  posts/[...slug].jl -> /posts/*
```

Routes are Julia files that return component functions. Dynamic params are accessible via the router.

## Tailwind CSS

Tailwind is enabled by default. Use conditional classes with `tw`:

```julia
Div(:class => tw("flex", "items-center", is_active && "bg-blue-500"))
```

## API Overview

### Reactivity

```julia
# Signals
count, set_count = create_signal(0)
count()        # read
set_count(5)   # write

# Effects (auto-track dependencies)
create_effect(() -> println("Count: ", count()))

# Memos (cached computations)
doubled = create_memo(() -> count() * 2)

# Batching
batch() do
    set_a(1)
    set_b(2)
end
```

### Elements

```julia
# JSX-style capitalized names
Div, Span, P, A, Button, Input, Form, Label
H1, H2, H3, H4, H5, H6
Ul, Ol, Li, Table, Tr, Td, Th
Img, Video, Audio
Header, Footer, Nav, Main, Section, Article
# ... and more
```

### Components

Components are just Julia functions that return VNodes:

```julia
function Greeting(name="World")
    P("Hello, ", name, "!")
end

# Use like any function
Div(Greeting("Julia"), Greeting("Therapy"))
```

### Conditional Rendering

```julia
Show(visible) do
    Div("I'm visible!")
end
```

## Live Demo

See Therapy.jl in action at [therapeuticjulia.github.io/Therapy.jl](https://therapeuticjulia.github.io/Therapy.jl/) — including an interactive Tic-Tac-Toe game with winner detection compiled entirely to WebAssembly.

## Current Status

| Feature | Status |
|---------|--------|
| Signals, Effects, Memos | ✅ |
| JSX-style elements | ✅ |
| SSR with hydration keys | ✅ |
| File-path routing | ✅ |
| Tailwind CSS | ✅ |
| Show conditional | ✅ |
| Direct IR → Wasm compilation | ✅ |
| Two-way input binding | ✅ |
| Theme binding (dark mode) | ✅ |
| Resources (async) | 🚧 |
| Context API | 🚧 |
| Server functions | 🚧 |

## Related Projects

- [WasmTarget.jl](https://github.com/TherapeuticJulia/WasmTarget.jl) - Julia to WebAssembly compiler

## License

MIT
