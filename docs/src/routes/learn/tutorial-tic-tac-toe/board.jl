# Step 2: Building the Board
#
# Creating the game board with a 3×3 grid

function TutorialBoard()
    TutorialLayout(
        Article(:class => "prose prose-stone dark:prose-invert max-w-none",
            Div(:class => "not-prose mb-8",
                Div(:class => "text-sm text-orange-500 dark:text-yellow-500 font-medium mb-2",
                    "Tutorial: Tic-Tac-Toe — Step 2 of 6"
                ),
                H1(:class => "text-3xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Building the Board"
                ),
                P(:class => "text-lg text-stone-500 dark:text-stone-400",
                    "Create the game board with a 3×3 grid of clickable squares."
                )
            ),

            H2("Create a Square component"),
            P("Let's start by creating a reusable Square component. Each square will be a button that can display X, O, or be empty:"),

            CodeBlock("""function Square(value)
    Button(
        :class => "w-16 h-16 bg-white text-3xl font-bold flex items-center justify-center border border-stone-300",
        value
    )
end"""),

            P("The ", Code("value"), " will be \"X\", \"O\", or empty string."),

            H2("Build the board grid"),
            P("Now let's create the Board component with 9 squares arranged in a 3×3 grid:"),

            CodeBlock("""function Board()
    Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 p-1 rounded",
        # Row 1
        Square("X"),
        Square("O"),
        Square("X"),
        # Row 2
        Square("O"),
        Square("X"),
        Square("O"),
        # Row 3
        Square(""),
        Square(""),
        Square("X")
    )
end"""),

            H2("Put it together"),
            P("Update your Game component to include the board:"),

            CodeBlock("""function Game()
    Div(:class => "flex flex-col items-center gap-4 p-8",
        H1(:class => "text-2xl font-bold", "Tic-Tac-Toe"),
        Board()
    )
end"""),

            P("Run it and you'll see a tic-tac-toe board with hardcoded values!"),

            # Visual preview
            Div(:class => "not-prose my-8 p-8 bg-stone-100 dark:bg-stone-800 rounded-xl flex justify-center",
                Div(:class => "grid grid-cols-3 gap-1 bg-stone-300 dark:bg-stone-600 p-1 rounded",
                    [Div(:class => "w-16 h-16 bg-white dark:bg-stone-700 text-3xl font-bold flex items-center justify-center text-stone-800 dark:text-stone-100", v)
                     for v in ["X", "O", "X", "O", "X", "O", "", "", "X"]]...
                )
            ),

            Div(:class => "not-prose my-8 p-6 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800",
                H3(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-2", "Key Concepts"),
                Ul(:class => "space-y-2 text-blue-700 dark:text-blue-300",
                    Li(Strong("Component composition"), " — ", Code("Board"), " uses ", Code("Square"), " components"),
                    Li(Strong("CSS Grid"), " — ", Code("grid grid-cols-3"), " creates the 3×3 layout"),
                    Li(Strong("Passing data"), " — Values are passed as function arguments")
                )
            ),

            P("But wait — the values are hardcoded! In the next step, we'll make the board dynamic using ", Strong("signals"), "."),

            TutorialNav("/learn/tutorial-tic-tac-toe/setup/", "/learn/tutorial-tic-tac-toe/state/", "Adding State")
        );
        current_path="/learn/tutorial-tic-tac-toe/board/"
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

TutorialBoard
