# Layout.jl - Main documentation layout component
#
# Pluto.jl-inspired theme with purple accents and dark mode support

using Therapy

"""
Main documentation layout with navigation and footer.
Uses Pluto.jl-inspired color scheme with dark mode support.
"""
function Layout(children...; title="Therapy.jl")
    Div(:class => "min-h-screen bg-slate-50 dark:bg-slate-900 transition-colors duration-200",
        # Navigation
        Nav(:class => "bg-white dark:bg-slate-800 shadow-sm border-b border-slate-200 dark:border-slate-700 transition-colors duration-200",
            Div(:class => "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8",
                Div(:class => "flex justify-between h-16",
                    # Logo
                    Div(:class => "flex items-center",
                        A(:href => "/", :class => "flex items-center",
                            Span(:class => "text-2xl font-bold text-violet-600 dark:text-violet-400", "Therapy"),
                            Span(:class => "text-2xl font-light text-slate-400 dark:text-slate-500", ".jl")
                        )
                    ),
                    # Navigation Links
                    Div(:class => "hidden sm:flex sm:items-center sm:space-x-6",
                        NavItem("/", "Home"),
                        NavItem("/getting-started/", "Getting Started"),
                        NavItem("/api/signals/", "API"),
                        NavItem("/examples/", "Examples"),
                        # GitHub link
                        A(:href => "https://github.com/TherapeuticJulia/Therapy.jl",
                          :class => "text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors",
                          :target => "_blank",
                            Svg(:class => "h-5 w-5", :fill => "currentColor", :viewBox => "0 0 24 24",
                                Path(:d => "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z")
                            )
                        ),
                        # Theme toggle placeholder - injected by build.jl
                        Div(:id => "theme-toggle", :class => "ml-2")
                    )
                )
            )
        ),

        # Main Content
        MainEl(:class => "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8",
            children...
        ),

        # Footer
        Footer(:class => "bg-white dark:bg-slate-800 border-t border-slate-200 dark:border-slate-700 mt-auto transition-colors duration-200",
            Div(:class => "max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8",
                Div(:class => "flex justify-between items-center",
                    P(:class => "text-slate-500 dark:text-slate-400 text-sm",
                        "Built with ",
                        A(:href => "/", :class => "text-violet-600 dark:text-violet-400 hover:text-violet-500 dark:hover:text-violet-300", "Therapy.jl"),
                        " - A reactive web framework for Julia"
                    ),
                    P(:class => "text-slate-400 dark:text-slate-500 text-sm",
                        "MIT License"
                    )
                )
            )
        )
    )
end

"""
Navigation item component with dark mode support.
"""
function NavItem(href, label)
    A(:href => href,
      :class => "text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white px-3 py-2 text-sm font-medium transition-colors",
      label)
end
