# Step 1: Setup
#
# Setting up a Therapy.jl project

function TutorialSetup()
    TutorialLayout(
        Article(:class => "prose prose-stone dark:prose-invert max-w-none",
            # Header with step indicator
            Div(:class => "not-prose mb-8",
                Div(:class => "text-sm text-orange-500 dark:text-yellow-500 font-medium mb-2",
                    "Tutorial: Tic-Tac-Toe — Step 1 of 6"
                ),
                H1(:class => "text-3xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Setup"
                ),
                P(:class => "text-lg text-stone-500 dark:text-stone-400",
                    "Set up your project and create a basic component."
                )
            ),

            # Content
            H2("Create a new project"),
            P("First, let's create a new Julia project for our game:"),

            CodeBlock("""mkdir tictactoe
cd tictactoe
julia --project=. -e 'using Pkg; Pkg.add(url="https://github.com/TherapeuticJulia/Therapy.jl")'"""),

            H2("Create your first component"),
            P("Create a new file called ", Code("game.jl"), " with a simple component:"),

            CodeBlock("""using Therapy

# A simple component that renders a greeting
function Game()
    Div(:class => "text-center p-8",
        H1(:class => "text-2xl font-bold", "Tic-Tac-Toe"),
        P("Let's build a game!")
    )
end

# Render to HTML
html = render_to_string(Game())
println(html)"""),

            H2("Run it"),
            P("Run your file to see the HTML output:"),

            CodeBlock("julia --project=. game.jl"),

            P("You should see HTML output like:"),

            CodeBlock("""<div class="text-center p-8">
  <h1 class="text-2xl font-bold">Tic-Tac-Toe</h1>
  <p>Let's build a game!</p>
</div>"""),

            # Key concepts callout
            Div(:class => "not-prose my-8 p-6 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-200 dark:border-blue-800",
                H3(:class => "text-lg font-semibold text-blue-800 dark:text-blue-200 mb-2", "Key Concepts"),
                Ul(:class => "space-y-2 text-blue-700 dark:text-blue-300",
                    Li(Strong("Components are functions"), " — ", Code("Game()"), " returns a VNode tree"),
                    Li(Strong("VNodes use capitalized names"), " — ", Code("Div"), ", ", Code("H1"), ", ", Code("P"), " (like JSX)"),
                    Li(Strong("Props use keyword pairs"), " — ", Code(":class => \"...\""))
                )
            ),

            # Navigation
            TutorialNav(nothing, "/learn/tutorial-tic-tac-toe/board/", "Building the Board")
        );
        current_path="/learn/tutorial-tic-tac-toe/setup/"
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

TutorialSetup
