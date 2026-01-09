# Describing the UI
#
# How to create and compose UI components in Therapy.jl

function DescribingUI()
    TutorialLayout(
        Div(:class => "space-y-8",
            # Header
            Div(:class => "mb-8",
                H1(:class => "text-3xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Describing the UI"
                ),
                P(:class => "text-lg text-stone-600 dark:text-stone-400",
                    "In Therapy.jl, UI is built from components — Julia functions that return elements."
                )
            ),

            # Components are Functions
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Components are Functions"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "A component is just a Julia function that returns a VNode (virtual DOM node):"
                ),
                CodeBlock("""function Greeting(name)
    Div(:class => "p-4 bg-blue-100 rounded",
        H1("Hello, ", name, "!"),
        P("Welcome to Therapy.jl")
    )
end

# Use it
Greeting("Julia")"""),
                P(:class => "text-stone-600 dark:text-stone-400 mt-4",
                    "This is similar to React's function components, but it's just regular Julia."
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Elements
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Elements"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Therapy.jl provides capitalized element functions that mirror HTML:"
                ),
                CodeBlock("""# Layout
Div(:class => "container", children...)
Span(:class => "text-red-500", "Error!")

# Text
H1("Title")
P("Paragraph")
Strong("Bold"), Em("Italic")

# Forms
Input(:type => "text", :placeholder => "Name...")
Button(:on_click => handler, "Click me")

# Lists
Ul(Li("One"), Li("Two"), Li("Three"))"""),
                Div(:class => "bg-stone-50 dark:bg-stone-900 rounded-lg p-4 mt-4",
                    P(:class => "text-stone-500 dark:text-stone-400 text-sm",
                        Strong("Why capitalized? "),
                        "Like JSX, capitalized names distinguish components from HTML strings. ",
                        Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "Div"),
                        " creates an element, ",
                        Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", "\"div\""),
                        " is just a string."
                    )
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Attributes
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Attributes"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Pass attributes as keyword-style pairs using ",
                    Code(:class => "bg-stone-200 dark:bg-stone-700 px-1 rounded", ":name => value"),
                    ":"
                ),
                CodeBlock("""# CSS classes
Div(:class => "flex items-center gap-4", ...)

# IDs and data attributes
Div(:id => "main", Symbol("data-testid") => "container", ...)

# Input attributes
Input(:type => "email", :placeholder => "you@example.com")

# Links
A(:href => "/about", :class => "underline", "About")""")
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Composition
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Composition"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Build complex UIs by composing smaller components:"
                ),
                CodeBlock("""function Avatar(url, name)
    Img(:src => url, :alt => name,
        :class => "w-10 h-10 rounded-full")
end

function UserCard(user)
    Div(:class => "flex items-center gap-3 p-4 border rounded",
        Avatar(user.avatar, user.name),
        Div(
            P(:class => "font-bold", user.name),
            P(:class => "text-sm text-gray-500", user.email)
        )
    )
end

function UserList(users)
    Div(:class => "space-y-2",
        [UserCard(u) for u in users]...
    )
end"""),
                Div(:class => "bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 mt-4",
                    P(:class => "text-green-800 dark:text-green-200 text-sm",
                        Strong("Julia power: "),
                        "Use comprehensions, map, filter — all your favorite Julia patterns work naturally."
                    )
                )
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Conditional Rendering
            Section(
                H2(:class => "text-2xl font-bold text-stone-800 dark:text-stone-100 mb-4",
                    "Conditional Rendering"
                ),
                P(:class => "text-stone-600 dark:text-stone-400 mb-4",
                    "Use Julia's ternary operator or if/else:"
                ),
                CodeBlock("""# Ternary
Div(
    is_logged_in ? UserMenu(user) : LoginButton()
)

# If/else in a function
function Status(online)
    if online
        Span(:class => "text-green-500", "Online")
    else
        Span(:class => "text-gray-400", "Offline")
    end
end

# Show component (reactive)
Show(is_visible) do
    Modal("Hello!")
end""")
            ),

            Hr(:class => "border-stone-200 dark:border-stone-700"),

            # Summary
            Div(:class => "bg-stone-100 dark:bg-stone-800 rounded-lg p-6",
                H3(:class => "text-lg font-semibold text-stone-800 dark:text-stone-200 mb-3",
                    "Summary"
                ),
                Ul(:class => "space-y-2 text-stone-600 dark:text-stone-400 text-sm",
                    Li(Strong("Components"), " are Julia functions returning VNodes"),
                    Li(Strong("Elements"), " are capitalized: Div, Span, Button, etc."),
                    Li(Strong("Attributes"), " use :name => value syntax"),
                    Li(Strong("Composition"), " works naturally with Julia's features")
                )
            ),

            # Next
            Div(:class => "mt-8",
                A(:href => "learn/adding-interactivity/",
                  :class => "text-orange-600 dark:text-yellow-400 font-medium",
                    "Next: Adding Interactivity →"
                )
            )
        );
        current_path="learn/describing-ui/"
    )
end

DescribingUI
