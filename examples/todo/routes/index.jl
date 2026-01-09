# Home Page - Todo List with reactive counter
using Therapy

function Page(params)
    # Create reactive state
    count, set_count = create_signal(0)
    todos, set_todos = create_signal([
        "Learn Therapy.jl",
        "Build something awesome",
        "Deploy to production"
    ])
    new_todo, set_new_todo = create_signal("")

    Div(:class => "space-y-8",
        # Counter Section
        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-lg font-semibold mb-4", "Reactive Counter"),
            Div(:class => "flex items-center gap-4",
                Button(
                    :class => "px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600",
                    :on_click => () -> set_count(count() - 1),
                    "-"
                ),
                Span(:class => "text-2xl font-bold w-16 text-center", count),
                Button(
                    :class => "px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600",
                    :on_click => () -> set_count(count() + 1),
                    "+"
                )
            )
        ),

        # Todo List Section
        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-lg font-semibold mb-4", "Todo List"),

            # Add todo form
            Div(:class => "flex gap-2 mb-4",
                Input(
                    :type => "text",
                    :class => "flex-1 px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500",
                    :placeholder => "Add a new todo...",
                    :value => new_todo,
                    :on_input => set_new_todo
                ),
                Button(
                    :class => "px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600",
                    :on_click => () -> begin
                        if !isempty(new_todo())
                            set_todos([todos()..., new_todo()])
                            set_new_todo("")
                        end
                    end,
                    "Add"
                )
            ),

            # Todo items (using regular Julia loop)
            Ul(:class => "space-y-2",
                [Li(:class => "flex items-center gap-2 p-2 bg-gray-50 rounded",
                    Span(:class => "flex-1", todo),
                    Button(
                        :class => "text-red-500 hover:text-red-700",
                        :on_click => () -> set_todos(filter(t -> t != todo, todos())),
                        "×"
                    )
                ) for todo in todos()]...
            )
        ),

        # Features Section
        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-lg font-semibold mb-4", "Features Demonstrated"),
            Ul(:class => "list-disc list-inside space-y-1 text-gray-600",
                Li("Fine-grained reactivity with signals"),
                Li("Capitalized JSX-style elements (Div, Button, etc.)"),
                Li("Tailwind CSS via CDN"),
                Li("File-based routing like Next.js"),
                Li("Event handlers compiled to WebAssembly"),
                Li("Server-side rendering with hydration")
            )
        )
    )
end

# Return the Page function
Page
