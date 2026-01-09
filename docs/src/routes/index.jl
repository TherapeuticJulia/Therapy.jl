# Home page
#
# Pluto.jl-inspired theme with violet/purple accents

function Index()
    Layout(
        # Hero Section
        Div(:class => "py-16 sm:py-24",
            Div(:class => "text-center",
                H1(:class => "text-4xl sm:text-6xl font-bold text-slate-900 dark:text-white tracking-tight",
                    "Reactive Web Apps",
                    Br(),
                    Span(:class => "text-violet-600 dark:text-violet-400", "in Pure Julia")
                ),
                P(:class => "mt-6 text-xl text-slate-500 dark:text-slate-400 max-w-2xl mx-auto",
                    "Build interactive web applications with fine-grained reactivity, server-side rendering, and WebAssembly compilation. Inspired by SolidJS and Leptos."
                ),
                Div(:class => "mt-10 flex justify-center gap-4",
                    A(:href => "/getting-started/",
                      :class => "bg-violet-600 hover:bg-violet-500 text-white px-6 py-3 rounded-lg font-medium transition-colors shadow-lg shadow-violet-500/25",
                      "Get Started"
                    ),
                    A(:href => "https://github.com/TherapeuticJulia/Therapy.jl",
                      :class => "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 px-6 py-3 rounded-lg font-medium hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors",
                      :target => "_blank",
                      "View on GitHub"
                    )
                )
            )
        ),

        # Feature Grid
        Div(:class => "py-16 bg-white dark:bg-slate-800 rounded-2xl shadow-sm transition-colors duration-200",
            H2(:class => "text-3xl font-bold text-center text-slate-900 dark:text-white mb-12",
                "Why Therapy.jl?"
            ),
            Div(:class => "grid md:grid-cols-3 gap-8 px-8",
                FeatureCard(
                    "Fine-Grained Reactivity",
                    "SolidJS-style signals and effects that update only what changes. No virtual DOM diffing.",
                    "M13 10V3L4 14h7v7l9-11h-7z"
                ),
                FeatureCard(
                    "Server-Side Rendering",
                    "Full SSR support with hydration. Fast initial page loads with interactive client-side updates.",
                    "M5 12h14M12 5l7 7-7 7"
                ),
                FeatureCard(
                    "WebAssembly Compilation",
                    "Compile Julia directly to Wasm for near-native performance in the browser.",
                    "M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
                )
            )
        ),

        # Code Example
        Div(:class => "py-16",
            H2(:class => "text-3xl font-bold text-center text-slate-900 dark:text-white mb-8",
                "Simple, Familiar API"
            ),
            Div(:class => "bg-slate-900 dark:bg-slate-950 rounded-xl p-6 max-w-3xl mx-auto overflow-x-auto shadow-xl",
                Pre(:class => "text-sm text-slate-100",
                    Code(:class => "language-julia", """using Therapy

function Counter()
    count, set_count = create_signal(0)

    Div(:class => "flex gap-4 items-center",
        Button(:on_click => () -> set_count(count() - 1), "-"),
        Span(:class => "text-2xl", count),
        Button(:on_click => () -> set_count(count() + 1), "+")
    )
end

# Render to HTML
html = render_to_string(Counter())""")
                )
            )
        ),

        # Interactive Demo Section
        Div(:class => "py-16 bg-gradient-to-r from-violet-600 to-purple-600 dark:from-violet-700 dark:to-purple-700 rounded-2xl text-white shadow-xl",
            Div(:class => "text-center px-8",
                H2(:class => "text-3xl font-bold mb-4",
                    "Try It Live"
                ),
                P(:class => "text-violet-100 mb-8 max-w-xl mx-auto",
                    "This counter is running in your browser as WebAssembly compiled from Julia using Therapy.jl. Click the buttons to see it in action!"
                ),
                # Placeholder - the actual compiled counter component is injected by build.jl
                Div(:class => "bg-white/10 backdrop-blur rounded-xl p-8 max-w-md mx-auto",
                    :id => "counter-demo",
                    "Loading..."
                )
            )
        )
    )
end

function FeatureCard(title, description, icon_path)
    Div(:class => "text-center p-6",
        Div(:class => "w-12 h-12 bg-violet-100 dark:bg-violet-900/50 rounded-lg flex items-center justify-center mx-auto mb-4",
            Svg(:class => "w-6 h-6 text-violet-600 dark:text-violet-400", :fill => "none", :viewBox => "0 0 24 24", :stroke => "currentColor", :stroke_width => "2",
                Path(:stroke_linecap => "round", :stroke_linejoin => "round", :d => icon_path)
            )
        ),
        H3(:class => "text-lg font-semibold text-slate-900 dark:text-white mb-2", title),
        P(:class => "text-slate-500 dark:text-slate-400", description)
    )
end

# Export the page component
Index
