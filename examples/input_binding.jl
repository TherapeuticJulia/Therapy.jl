# Input Binding Example - Two-way data binding
#
# Shows how to bind input elements to signals.
# The input value and the display are synchronized.

using Therapy

function InputDemo()
    count, set_count = create_signal(42)

    divv(:class => "demo",
        h1("Two-Way Input Binding"),

        # Display the current value
        p("Current value: ", span(count)),

        # Input bound to the signal
        # Using direct setter pattern: :on_input => set_count
        divv(:class => "input-group",
            label("Enter a number: "),
            input(:type => "number", :value => count, :on_input => set_count)
        ),

        # Buttons still work too
        divv(:class => "buttons",
            button(:on_click => () -> set_count(count() - 1), "-1"),
            button(:on_click => () -> set_count(count() + 1), "+1"),
            button(:on_click => () -> set_count(0), "Reset")
        )
    )
end

compile_and_serve(InputDemo, title="Input Binding Demo", port=8082)
