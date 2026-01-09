using Test
using Therapy

@testset "Therapy.jl" begin

    @testset "Signals" begin
        @testset "basic signal" begin
            count, set_count = create_signal(0)
            @test count() == 0
            set_count(5)
            @test count() == 5
        end

        @testset "signal with different types" begin
            name, set_name = create_signal("hello")
            @test name() == "hello"
            set_name("world")
            @test name() == "world"

            pi_val, set_pi = create_signal(3.14)
            @test pi_val() == 3.14

            flag, set_flag = create_signal(true)
            @test flag() == true
            set_flag(false)
            @test flag() == false
        end

        @testset "signal with transform" begin
            upper, set_upper = create_signal("hello", uppercase)
            @test upper() == "HELLO"
            set_upper("world")
            @test upper() == "WORLD"
        end
    end

    @testset "Effects" begin
        @testset "basic effect" begin
            count, set_count = create_signal(0)
            log = Int[]

            create_effect() do
                push!(log, count())
            end

            @test log == [0]  # Effect runs immediately

            set_count(1)
            @test log == [0, 1]

            set_count(2)
            @test log == [0, 1, 2]
        end

        @testset "effect with multiple signals" begin
            a, set_a = create_signal(1)
            b, set_b = create_signal(2)
            sums = Int[]

            create_effect() do
                push!(sums, a() + b())
            end

            @test sums == [3]

            set_a(10)
            @test sums == [3, 12]

            set_b(20)
            @test sums == [3, 12, 30]
        end

        @testset "effect disposal" begin
            count, set_count = create_signal(0)
            log = Int[]

            effect = create_effect() do
                push!(log, count())
            end

            @test log == [0]

            dispose!(effect)
            set_count(1)
            @test log == [0]  # Effect no longer runs
        end
    end

    @testset "Memos" begin
        @testset "basic memo" begin
            count, set_count = create_signal(1)
            doubled = create_memo(() -> count() * 2)

            @test doubled() == 2

            set_count(5)
            @test doubled() == 10
        end

        @testset "memo caching" begin
            count, set_count = create_signal(1)
            call_count = Ref(0)

            expensive = create_memo() do
                call_count[] += 1
                count() * 2
            end

            @test expensive() == 2
            @test call_count[] == 1

            # Reading again shouldn't recompute
            @test expensive() == 2
            @test call_count[] == 1

            # Changing dependency should recompute
            set_count(5)
            @test expensive() == 10
            @test call_count[] == 2
        end
    end

    @testset "Batching" begin
        @testset "batch updates" begin
            a, set_a = create_signal(0)
            b, set_b = create_signal(0)
            runs = Int[]

            create_effect() do
                push!(runs, a() + b())
            end

            @test runs == [0]

            batch() do
                set_a(1)
                set_b(2)
            end

            # Effect should only run once after batch
            @test runs == [0, 3]
        end
    end

    @testset "VNodes" begin
        @testset "basic vnode" begin
            node = VNode(:div, Dict{Symbol,Any}(), Any["hello"])
            @test node.tag == :div
            @test node.children == ["hello"]
        end

        @testset "element functions" begin
            node = Div(:class => "container", "Hello")
            @test node.tag == :div
            @test node.props[:class] == "container"
            @test node.children == ["Hello"]
        end

        @testset "nested elements" begin
            node = Div(
                H1("Title"),
                P("Paragraph")
            )
            @test length(node.children) == 2
            @test node.children[1].tag == :h1
            @test node.children[2].tag == :p
        end
    end

    @testset "Components" begin
        @testset "basic component" begin
            Greeting = component(:Greeting) do props
                name = get_prop(props, :name, "World")
                P("Hello, ", name, "!")
            end

            instance = Greeting(:name => "Julia")
            @test instance isa Therapy.ComponentInstance

            node = render_component(instance)
            @test node.tag == :p
        end

        @testset "component with children" begin
            Card = component(:Card) do props
                Div(:class => "card", get_children(props)...)
            end

            instance = Card(P("Content"))
            node = render_component(instance)
            @test node.tag == :div
            @test length(node.children) == 1
        end
    end

    @testset "SSR" begin
        @testset "basic rendering" begin
            html = render_to_string(Div("Hello"))
            @test occursin("<div", html)
            @test occursin("Hello", html)
            @test occursin("</div>", html)
        end

        @testset "with attributes" begin
            html = render_to_string(Div(:class => "container", "Content"))
            @test occursin("class=\"container\"", html)
        end

        @testset "nested elements" begin
            html = render_to_string(
                Div(
                    H1("Title"),
                    P("Paragraph")
                )
            )
            @test occursin("<h1", html)
            @test occursin("</h1>", html)
            @test occursin("<p", html)
            @test occursin("</p>", html)
        end

        @testset "hydration keys" begin
            html = render_to_string(Div("Hello"))
            @test occursin("data-hk=", html)
        end

        @testset "void elements" begin
            html = render_to_string(Img(:src => "test.jpg"))
            @test occursin("<img", html)
            @test occursin("/>", html)
            @test !occursin("</img>", html)
        end

        @testset "boolean attributes" begin
            html = render_to_string(Input(:type => "checkbox", :checked => true))
            @test occursin(" checked", html)
        end

        @testset "escaping" begin
            html = render_to_string(P("<script>alert('xss')</script>"))
            @test !occursin("<script>", html)
            @test occursin("&lt;script&gt;", html)
        end

        @testset "signal values" begin
            count, _ = create_signal(42)
            html = render_to_string(P(count))
            @test occursin("42", html)
        end

        @testset "component rendering" begin
            Greeting = component(:Greeting) do props
                P("Hello, ", get_prop(props, :name, "World"), "!")
            end

            html = render_to_string(Greeting(:name => "Julia"))
            @test occursin("Hello, Julia!", html)
        end
    end

    @testset "Show conditional" begin
        result = Show(true, () -> Div("visible"))
        @test result.tag == :div

        result = Show(false, () -> Div("visible"))
        @test result === nothing
    end

end

println("\nAll tests passed!")
