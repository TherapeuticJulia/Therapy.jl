# Analysis.jl - Analyze components to extract reactive structure
#
# This module runs a component and tracks:
# - Signals created (state)
# - Event handlers defined
# - DOM structure with signal bindings

"""
Represents a signal discovered during component analysis.
"""
struct AnalyzedSignal
    id::UInt64
    name::Symbol
    initial_value::Any
    type::Type
end

"""
Represents an event handler discovered during component analysis.
"""
struct AnalyzedHandler
    id::Int
    event::Symbol           # :on_click, :on_input, etc.
    target_hk::Int          # Hydration key of the element
    handler::Function       # The actual handler function
    operations::Vector{TracedOperation}  # What operations the handler performs
end

"""
Represents a DOM binding where a signal value is displayed.
"""
struct AnalyzedBinding
    signal_id::UInt64
    target_hk::Int          # Hydration key of the element to update
    attribute::Union{Symbol, Nothing}  # nothing for text content, :class, :value, etc.
end

"""
Represents a two-way input binding.
The input's value is bound to a signal, and changes update the signal.
"""
struct AnalyzedInputBinding
    signal_id::UInt64       # The signal bound to this input
    target_hk::Int          # Hydration key of the input element
    handler_id::Int         # ID of the generated handler
    input_type::Symbol      # :text, :number, :checkbox, etc.
end

"""
Represents a Show conditional rendering node.
"""
struct AnalyzedShow
    signal_id::UInt64       # The signal that controls visibility
    target_hk::Int          # Hydration key of the Show wrapper
    initial_visible::Bool   # Initial visibility state
end

"""
Result of analyzing a component.
"""
struct ComponentAnalysis
    signals::Vector{AnalyzedSignal}
    handlers::Vector{AnalyzedHandler}
    bindings::Vector{AnalyzedBinding}
    input_bindings::Vector{AnalyzedInputBinding}
    show_nodes::Vector{AnalyzedShow}
    vnode::Any
    html::String
end

"""
    analyze_component(component_fn::Function) -> ComponentAnalysis

Analyze a component to extract its reactive structure.

This runs the component once to discover:
- What signals it creates
- What event handlers it defines
- How signals bind to the DOM
"""
function analyze_component(component_fn::Function)
    # Enable signal tracking mode
    enable_signal_analysis!()

    local vnode
    local raw_signals
    local getter_map

    try
        # Run the component to get its VNode structure
        vnode = component_fn()

        # Get the signals that were created
        raw_signals, getter_map = disable_signal_analysis!()
    catch e
        disable_signal_analysis!()
        rethrow(e)
    end

    # Convert raw signals to AnalyzedSignal
    signals = AnalyzedSignal[]
    for s in raw_signals
        push!(signals, AnalyzedSignal(
            s.id,
            Symbol("signal_", s.id),
            s.initial,
            s.type
        ))
    end

    # Build setter map for input binding detection
    setter_map = Dict{Function, UInt64}()
    for s in raw_signals
        setter_map[s.setter] = s.id
    end

    # Walk the VNode tree to find event handlers and signal bindings
    raw_handlers = Tuple{Int, Symbol, Int, Function}[]  # (id, event, hk, handler)
    bindings = AnalyzedBinding[]
    input_bindings = AnalyzedInputBinding[]
    show_nodes = AnalyzedShow[]
    hk_counter = Ref(0)
    handler_counter = Ref(0)

    analyze_vnode!(vnode, raw_handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)

    # Trace each handler to discover what operations it performs
    handlers = AnalyzedHandler[]
    for (h_id, h_event, h_hk, h_fn) in raw_handlers
        ops = trace_handler(h_fn, raw_signals)
        push!(handlers, AnalyzedHandler(h_id, h_event, h_hk, h_fn, ops))
    end

    # Generate HTML with hydration keys
    html = render_to_string(vnode)

    return ComponentAnalysis(signals, handlers, bindings, input_bindings, show_nodes, vnode, html)
end

"""
Recursively analyze a VNode tree.
"""
function analyze_vnode!(node::VNode, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
    hk_counter[] += 1
    hk = hk_counter[]

    # Track if this is an input element with a value binding
    is_input = node.tag == :input
    value_signal_id = nothing
    input_type = :text

    # Check props for event handlers and signal bindings
    for (key, value) in node.props
        key_str = string(key)

        # Get input type if present
        if key == :type && value isa String
            input_type = Symbol(value)
        end

        if startswith(key_str, "on_")
            # Event handler - store as tuple for later tracing
            if value isa Function
                # Check if this is a direct setter (for input binding)
                setter_signal_id = get(setter_map, value, nothing)
                if is_input && key == :on_input && setter_signal_id !== nothing
                    # This is a two-way input binding with direct setter
                    value_signal_id = setter_signal_id
                    handler_counter[] += 1
                    push!(input_bindings, AnalyzedInputBinding(
                        setter_signal_id,
                        hk,
                        handler_counter[],
                        input_type
                    ))
                else
                    # Regular event handler
                    handler_counter[] += 1
                    push!(handlers, (handler_counter[], key, hk, value))
                end
            end
        elseif value isa Function
            # Check if it's a signal getter (use local getter_map, not global)
            signal_id = get(getter_map, value, nothing)
            if signal_id !== nothing
                push!(bindings, AnalyzedBinding(signal_id, hk, key))
                # Track value binding for input elements
                if is_input && key == :value
                    value_signal_id = signal_id
                end
            end
        end
    end

    # Check children for signal bindings and nested nodes
    for child in node.children
        if child isa VNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa ShowNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa Fragment
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa Function
            # Check if it's a signal getter (use local getter_map, not global)
            signal_id = get(getter_map, child, nothing)
            if signal_id !== nothing
                # Signal bound to text content - bind to this element's hk
                push!(bindings, AnalyzedBinding(signal_id, hk, nothing))
            end
        elseif child isa ComponentInstance
            rendered = render_component(child)
            if rendered isa VNode
                analyze_vnode!(rendered, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
            end
        end
    end
end

function analyze_vnode!(node::ShowNode, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
    # Show wrapper gets its own hydration key
    hk_counter[] += 1
    hk = hk_counter[]

    # Check if the condition is a signal getter
    signal_id = get(getter_map, node.condition, nothing)
    if signal_id !== nothing
        push!(show_nodes, AnalyzedShow(signal_id, hk, node.initial_visible))
    end

    # Analyze the content inside the Show
    if node.content !== nothing
        if node.content isa VNode
            analyze_vnode!(node.content, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        elseif node.content isa Fragment
            analyze_vnode!(node.content, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        end
    end
end

function analyze_vnode!(node::Fragment, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
    for child in node.children
        if child isa VNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        elseif child isa ShowNode
            analyze_vnode!(child, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
        end
    end
end

function analyze_vnode!(node, handlers, bindings, input_bindings, show_nodes, getter_map, setter_map, hk_counter, handler_counter)
    # Primitive values, strings, etc. - nothing to analyze
end

"""
Trace a handler to discover what signal operations it performs.

This runs the handler multiple times with different starting values
to disambiguate operations (e.g., +1 vs ×2 when starting from 1).
"""
function trace_handler(handler::Function, raw_signals)::Vector{TracedOperation}
    # Use multiple test values to disambiguate operations
    # Include 0 and 1 for toggle detection, plus larger values for arithmetic
    test_values = [0, 1, 10]

    results_per_signal = Dict{UInt64, Vector{Tuple{Any, Any}}}()  # signal_id -> [(old, new), ...]

    for test_val in test_values
        # Set all signals to test value
        for s in raw_signals
            if s.type <: Integer
                s.setter(test_val)
            end
        end

        # Enable tracing and run the handler
        enable_handler_tracing!()
        try
            handler()
        catch e
            # Handler might fail - that's OK
        end
        traced = disable_handler_tracing!()

        # Record old/new pairs for analysis
        for op in traced
            if !haskey(results_per_signal, op.signal_id)
                results_per_signal[op.signal_id] = Tuple{Any, Any}[]
            end
            # Reconstruct old value from test_val and the operation
            old_val = test_val
            new_val = get_signal_value_by_id(raw_signals, op.signal_id)
            push!(results_per_signal[op.signal_id], (old_val, new_val))
        end
    end

    # Analyze results to determine actual operations
    ops = TracedOperation[]
    for (signal_id, pairs) in results_per_signal
        if length(pairs) >= 3
            # We have 3 samples (0, 1, 10) - check for toggle pattern
            op = disambiguate_operation_3(pairs)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        elseif length(pairs) >= 2
            (old1, new1) = pairs[1]
            (old2, new2) = pairs[2]
            op = disambiguate_operation(old1, new1, old2, new2)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        elseif length(pairs) == 1
            (old_val, new_val) = pairs[1]
            op = detect_operation(old_val, new_val)
            push!(ops, TracedOperation(signal_id, op.operation, op.operand))
        end
    end

    # Restore original signal values
    for s in raw_signals
        s.setter(s.initial)
    end

    return ops
end

"""
Get a signal's current value by its ID.
"""
function get_signal_value_by_id(raw_signals, signal_id::UInt64)
    for s in raw_signals
        if s.id == signal_id
            return s.getter()
        end
    end
    return nothing
end

"""
Disambiguate operation using two test samples.
"""
function disambiguate_operation(old1, new1, old2, new2)
    diff1 = new1 - old1
    diff2 = new2 - old2

    # Check for constant SET (both results are the same regardless of input)
    if new1 == new2
        return (operation=OP_SET, operand=new1)
    end

    # Check for consistent additive offset (ADD/SUB/INCREMENT/DECREMENT)
    if diff1 == diff2
        if diff1 == 1
            return (operation=OP_INCREMENT, operand=nothing)
        elseif diff1 == -1
            return (operation=OP_DECREMENT, operand=nothing)
        elseif diff1 > 0
            return (operation=OP_ADD, operand=diff1)
        else
            return (operation=OP_SUB, operand=-diff1)
        end
    end

    # Check for multiplication (ratio is consistent)
    if old1 != 0 && old2 != 0
        ratio1 = new1 / old1
        ratio2 = new2 / old2
        if ratio1 == ratio2 && ratio1 == floor(ratio1)
            return (operation=OP_MUL, operand=Int(ratio1))
        end
    end

    # Check for negation
    if new1 == -old1 && new2 == -old2
        return (operation=OP_NEGATE, operand=nothing)
    end

    # Fallback to SET with first new value
    return (operation=OP_SET, operand=new1)
end

"""
Disambiguate operation using three test samples (0, 1, 10).
This enables detection of toggle patterns.
"""
function disambiguate_operation_3(pairs::Vector{Tuple{Any, Any}})
    # Expected pairs from test values [0, 1, 10]:
    # pairs[1] = (0, result_when_0)
    # pairs[2] = (1, result_when_1)
    # pairs[3] = (10, result_when_10)

    (old0, new0) = pairs[1]  # When input is 0
    (old1, new1) = pairs[2]  # When input is 1
    (old10, new10) = pairs[3]  # When input is 10

    # Check for toggle pattern: 0→1 and nonzero→0
    if old0 == 0 && new0 == 1 && new1 == 0 && new10 == 0
        return (operation=OP_TOGGLE, operand=nothing)
    end

    # Check for constant SET (all results the same)
    if new0 == new1 == new10
        return (operation=OP_SET, operand=new0)
    end

    # Check for consistent additive offset
    diff1 = new1 - old1
    diff10 = new10 - old10
    if diff1 == diff10
        if diff1 == 1
            return (operation=OP_INCREMENT, operand=nothing)
        elseif diff1 == -1
            return (operation=OP_DECREMENT, operand=nothing)
        elseif diff1 > 0
            return (operation=OP_ADD, operand=diff1)
        else
            return (operation=OP_SUB, operand=-diff1)
        end
    end

    # Check for multiplication (using non-zero values)
    if old1 != 0 && old10 != 0
        ratio1 = new1 / old1
        ratio10 = new10 / old10
        if ratio1 == ratio10 && ratio1 == floor(ratio1)
            return (operation=OP_MUL, operand=Int(ratio1))
        end
    end

    # Check for negation
    if new1 == -old1 && new10 == -old10
        return (operation=OP_NEGATE, operand=nothing)
    end

    # Fallback to 2-sample disambiguation
    return disambiguate_operation(old1, new1, old10, new10)
end
