# Simple Counter Example - The Therapy.jl Way
#
# This shows how easy it is to build reactive web apps:
# 1. Write your component with signals
# 2. Call compile_and_serve()
# 3. Open browser - it just works!

using Therapy

# =============================================================================
# DEFINE YOUR COMPONENT - Just normal Therapy.jl code!
# =============================================================================

function Counter()
    # Create reactive state
    count, set_count = create_signal(0)

    # Return the UI
    divv(:class => "counter",
        h1("Therapy.jl Counter"),
        p("Count: ", span(count)),
        divv(:class => "buttons",
            button(:on_click => () -> set_count(count() - 1), "-"),
            button(:on_click => () -> set_count(count() + 1), "+")
        )
    )
end

# =============================================================================
# COMPILE AND SERVE - One line to run your app!
# =============================================================================

compile_and_serve(Counter, title="Counter Demo")
