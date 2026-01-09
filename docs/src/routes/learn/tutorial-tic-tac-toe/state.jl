# Step 3: Adding State
#
# Using signals to track board state

function TutorialState()
    TutorialLayout(
        Article(:class => "prose prose-stone dark:prose-invert max-w-none",
            Div(:class => "not-prose mb-8",
                Div(:class => "text-sm text-orange-500 dark:text-yellow-500 font-medium mb-2",
                    "Tutorial: Tic-Tac-Toe — Step 3 of 6"
                ),
                H1(:class => "text-3xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Adding State"
                ),
                P(:class => "text-lg text-stone-500 dark:text-stone-400",
                    "Use signals to make the board interactive."
                )
            ),

            H2("What are signals?"),
            P("Signals are Therapy.jl's reactive primitives. They hold values that can change over time, and the UI automatically updates when they change."),

            CodeBlock("""# Create a signal with initial value 0
count, set_count = create_signal(0)

# Read the value
current = count()  # => 0

# Update the value
set_count(5)
count()  # => 5"""),

            P("When you call ", Code("create_signal"), ", you get two things:"),
            Ul(
                Li(Strong("A getter function"), " — call it to read the current value"),
                Li(Strong("A setter function"), " — call it to update the value")
            ),

            H2("Add state to a square"),
            P("Let's make a single square that tracks its own state. We'll use numbers to represent the state:"),
            Ul(
                Li(Code("0"), " = empty"),
                Li(Code("1"), " = X"),
                Li(Code("2"), " = O")
            ),

            CodeBlock("""function InteractiveSquare()
    # Create signal for this square's value
    value, set_value = create_signal(0)

    Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold",
        # Update on click: cycle through empty → X → O → empty
        :on_click => () -> set_value((value() + 1) % 3),
        # Display: convert number to symbol
        value() == 0 ? "" : (value() == 1 ? "X" : "O")
    )
end"""),

            Div(:class => "not-prose my-8 p-6 bg-amber-50 dark:bg-amber-900/20 rounded-xl border border-amber-200 dark:border-amber-800",
                H3(:class => "text-lg font-semibold text-amber-800 dark:text-amber-200 mb-2", "Why numbers instead of strings?"),
                P(:class => "text-amber-700 dark:text-amber-300",
                    "Therapy.jl compiles to WebAssembly, which works with numeric types. Using ", Code("0/1/2"), " instead of ", Code("\"\""), "/", Code("\"X\""), "/", Code("\"O\""), " gives us efficient Wasm code."
                )
            ),

            H2("The magic: automatic updates"),
            P("Here's the beautiful part: when you call ", Code("set_value()"), ", Therapy.jl automatically:"),
            Ol(
                Li("Updates the Wasm global variable"),
                Li("Calls the DOM update to change the button text"),
                Li("No manual DOM manipulation needed!")
            ),

            P("The ", Code(":on_click"), " handler is a Julia closure that gets compiled to a Wasm function. When you click the button, the Wasm function runs and updates the signal."),

            Div(:class => "not-prose my-8 p-6 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800",
                H3(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-2", "Key Concepts"),
                Ul(:class => "space-y-2 text-blue-700 dark:text-blue-300",
                    Li(Strong("Signals"), " — reactive state with ", Code("create_signal(initial_value)")),
                    Li(Strong("Reading"), " — call the getter: ", Code("value()")),
                    Li(Strong("Writing"), " — call the setter: ", Code("set_value(new_value)")),
                    Li(Strong("Automatic updates"), " — UI updates when signals change")
                )
            ),

            P("Now that we understand signals, let's use them to implement proper game turns."),

            TutorialNav("/learn/tutorial-tic-tac-toe/board/", "/learn/tutorial-tic-tac-toe/turns/", "Taking Turns")
        );
        current_path="/learn/tutorial-tic-tac-toe/state/"
    )
end

function CodeBlock(code)
    Div(:class => "not-prose bg-stone-800 dark:bg-stone-950 rounded-lg overflow-x-auto shadow-lg my-4",
        Pre(:class => "p-4 text-sm text-stone-100",
            Code(:class => "language-julia", code)
        )
    )
end

function TutorialNav(prev_href, next_href, next_label)
    Div(:class => "not-prose flex justify-between items-center mt-12 pt-8 border-t border-stone-200 dark:border-stone-700",
        prev_href !== nothing ?
            A(:href => prev_href, :class => "text-stone-600 dark:text-stone-400 hover:text-stone-900 dark:hover:text-stone-100", "← Previous") :
            Div(),
        next_href !== nothing ?
            A(:href => next_href,
              :class => "flex items-center gap-2 bg-orange-200 dark:bg-yellow-900/50 hover:bg-orange-300 dark:hover:bg-yellow-900/70 text-stone-800 dark:text-yellow-100 px-4 py-2 rounded-lg font-medium transition-colors",
              "Next: $next_label →"
            ) :
            Div()
    )
end

TutorialState
