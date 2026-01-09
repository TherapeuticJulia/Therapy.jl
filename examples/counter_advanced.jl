# Advanced Counter Example - Multiple Operations
#
# Tests various signal operations:
# - Increment by 1
# - Decrement by 1
# - Add by 5
# - Multiply by 2
# - Reset to 0

using Therapy

function AdvancedCounter()
    count, set_count = create_signal(1)  # Start at 1 for multiply test

    divv(:class => "counter",
        h1("Advanced Counter"),
        p("Count: ", span(count)),
        divv(:class => "buttons",
            button(:on_click => () -> set_count(count() - 1), "-1"),
            button(:on_click => () -> set_count(count() + 1), "+1"),
            button(:on_click => () -> set_count(count() + 5), "+5"),
            button(:on_click => () -> set_count(count() * 2), "×2"),
            button(:on_click => () -> set_count(0), "Reset")
        )
    )
end

compile_and_serve(AdvancedCounter, title="Advanced Counter", port=8081)
