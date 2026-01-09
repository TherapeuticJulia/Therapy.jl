# Counter Example for Therapy.jl
# This demonstrates the core reactive patterns

using Therapy

# Define a Counter component
Counter = component(:Counter) do props
    # Create a reactive signal for the count
    initial = get_prop(props, :initial, 0)
    count, set_count = create_signal(initial)

    # Create a memo for derived state
    doubled = create_memo(() -> count() * 2)

    # Create an effect for side effects (logging)
    create_effect() do
        println("Count changed to: ", count())
    end

    # Return the component's VNode tree (JSX-style capitalized elements)
    Div(:class => "counter",
        H2("Counter Example"),
        P("Current count: ", Span(:class => "count", count)),
        P("Doubled: ", Span(:class => "doubled", doubled)),
        Div(:class => "buttons",
            Button(:on_click => () -> set_count(count() - 1), "-"),
            Button(:on_click => () -> set_count(count() + 1), "+"),
            Button(:on_click => () -> set_count(0), "Reset")
        )
    )
end

# Render the counter to an HTML string (SSR)
println("=== Server-Side Rendering ===")
html = render_to_string(Counter(:initial => 5))
println(html)
println()

# Demonstrate reactive updates
println("=== Reactive Updates Demo ===")
count, set_count = create_signal(0)

# This effect will log whenever count changes
create_effect() do
    println("Effect: count is now ", count())
end

println("\nSetting count to 1...")
set_count(1)

println("\nSetting count to 2...")
set_count(2)

println("\nBatching multiple updates...")
batch() do
    set_count(10)
    set_count(20)
    set_count(30)
end
println("After batch, count is: ", count())

# Demonstrate memos
println("\n=== Memo Demo ===")
a, set_a = create_signal(2)
b, set_b = create_signal(3)

product = create_memo() do
    println("Computing product...")
    a() * b()
end

println("Product: ", product())
println("Product again (cached): ", product())

set_a(5)
println("After setting a=5, product: ", product())
