# About Page
using Therapy

function Page(params)
    Div(:class => "space-y-6",
        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-2xl font-bold mb-4", "About Therapy.jl"),
            P(:class => "text-gray-600 mb-4",
                "Therapy.jl is a reactive web framework for Julia inspired by ",
                A(:href => "https://leptos.dev", :class => "text-blue-500 hover:underline", "Leptos"),
                " and ",
                A(:href => "https://solidjs.com", :class => "text-blue-500 hover:underline", "SolidJS"),
                "."
            ),
            P(:class => "text-gray-600",
                "It features fine-grained reactivity, server-side rendering, ",
                "and compilation to WebAssembly for blazing-fast client-side updates."
            )
        ),

        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-xl font-bold mb-4", "Key Features"),
            Ul(:class => "space-y-3",
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("Fine-grained reactivity with signals (no virtual DOM)")
                ),
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("JSX-style capitalized elements (Div, Button, Span)")
                ),
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("File-based routing like Next.js")
                ),
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("Built-in Tailwind CSS support")
                ),
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("SSR with hydration")
                ),
                Li(:class => "flex items-start gap-2",
                    Span(:class => "text-green-500", "✓"),
                    Span("Compiles to WebAssembly via WasmTarget.jl")
                )
            )
        ),

        Section(:class => "bg-white rounded-lg shadow p-6",
            H2(:class => "text-xl font-bold mb-4", "Example Code"),
            Pre(:class => "bg-gray-900 text-gray-100 p-4 rounded overflow-x-auto text-sm",
                Code("""
using Therapy

function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end
""")
            )
        ),

        Div(:class => "text-center",
            A(
                :href => "/",
                :class => "inline-block px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600",
                "← Back to Home"
            )
        )
    )
end

Page
