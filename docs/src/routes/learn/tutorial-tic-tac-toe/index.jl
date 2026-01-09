# Tutorial: Tic-Tac-Toe
#
# Main tutorial page with interactive game preview and introduction

function TicTacToeTutorial()
    TutorialLayout(
        Article(:class => "prose prose-stone dark:prose-invert max-w-none",
            # Header
            Div(:class => "mb-8 not-prose",
                H1(:class => "text-4xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Tutorial: Tic-Tac-Toe"
                ),
                P(:class => "text-xl text-stone-500 dark:text-stone-400",
                    "Build a complete tic-tac-toe game with Therapy.jl. You'll learn signals, event handlers, and component composition."
                )
            ),

            # Interactive Game Preview
            Div(:class => "not-prose bg-gradient-to-r from-orange-100 to-orange-200 dark:from-yellow-950/30 dark:to-yellow-900/30 rounded-xl p-8 mb-8",
                Div(:class => "text-center mb-6",
                    H2(:class => "text-xl font-bold text-stone-800 dark:text-stone-100 mb-2",
                        "What You'll Build"
                    ),
                    P(:class => "text-stone-600 dark:text-stone-300",
                        "This is the final result - a fully interactive game running as WebAssembly."
                    )
                ),
                Div(:class => "flex justify-center",
                    :id => "tictactoe-demo",
                    Div(:class => "text-stone-400", "Loading game...")
                )
            ),

            # Introduction
            H2("What you'll learn"),
            P("In this tutorial, you'll build a small tic-tac-toe game. This tutorial doesn't assume any existing Therapy.jl knowledge. The techniques you'll learn are fundamental to building any Therapy.jl app:"),
            Ul(
                Li(Strong("Signals"), " — reactive state that automatically tracks changes"),
                Li(Strong("Components"), " — reusable UI building blocks"),
                Li(Strong("Event handlers"), " — Julia closures that respond to user input"),
                Li(Strong("Wasm compilation"), " — your Julia code runs in the browser")
            ),

            # Prerequisites
            H2("Prerequisites"),
            P("This tutorial assumes you have:"),
            Ul(
                Li("Julia 1.9 or later installed"),
                Li("Basic familiarity with Julia syntax"),
                Li("Therapy.jl installed (", Code("Pkg.add(url=\"https://github.com/TherapeuticJulia/Therapy.jl\")"), ")")
            ),

            # What we'll build
            H2("Overview of the steps"),
            P("We'll build the game step by step:"),

            # Step cards
            Div(:class => "not-prose grid gap-4 my-8",
                StepCard(1, "Setup", "Set up your project and create a basic component", "/learn/tutorial-tic-tac-toe/setup/"),
                StepCard(2, "Building the Board", "Create the game board with a 3×3 grid of squares", "/learn/tutorial-tic-tac-toe/board/"),
                StepCard(3, "Adding State", "Use signals to track the board state", "/learn/tutorial-tic-tac-toe/state/"),
                StepCard(4, "Taking Turns", "Implement the game logic for X and O turns", "/learn/tutorial-tic-tac-toe/turns/"),
                StepCard(5, "Declaring a Winner", "Add logic to detect when someone wins", "/learn/tutorial-tic-tac-toe/winner/"),
                StepCard(6, "Complete Game", "Review the final code and next steps", "/learn/tutorial-tic-tac-toe/complete/")
            ),

            # Get started
            Div(:class => "not-prose mt-12 p-6 bg-orange-100/50 dark:bg-yellow-950/30 rounded-xl",
                Div(:class => "flex items-center justify-between",
                    Div(
                        H3(:class => "text-lg font-semibold text-stone-800 dark:text-stone-100", "Ready to start?"),
                        P(:class => "text-stone-600 dark:text-stone-400", "Let's set up your first Therapy.jl project.")
                    ),
                    A(:href => "/learn/tutorial-tic-tac-toe/setup/",
                      :class => "bg-orange-200 dark:bg-yellow-900/50 hover:bg-orange-300 dark:hover:bg-yellow-900/70 text-stone-800 dark:text-yellow-100 px-6 py-3 rounded-lg font-medium transition-colors",
                      "Start Tutorial →"
                    )
                )
            )
        );
        current_path="/learn/tutorial-tic-tac-toe/"
    )
end

function StepCard(number, title, description, href)
    A(:href => href, :class => "block",
        Div(:class => "flex gap-4 p-4 bg-white dark:bg-stone-800 rounded-lg border border-stone-200 dark:border-stone-700 hover:border-orange-200 dark:hover:border-yellow-900 transition-colors",
            # Step number
            Div(:class => "flex-shrink-0 w-10 h-10 rounded-full bg-orange-100 dark:bg-yellow-950/50 text-orange-600 dark:text-yellow-500 flex items-center justify-center font-bold",
                string(number)
            ),
            # Content
            Div(
                H4(:class => "font-medium text-stone-800 dark:text-stone-100", title),
                P(:class => "text-sm text-stone-500 dark:text-stone-400", description)
            )
        )
    )
end

TicTacToeTutorial
