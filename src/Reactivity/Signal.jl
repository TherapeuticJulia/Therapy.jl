# Signal.jl - Core reactive primitive

# Global signal ID counter
const SIGNAL_ID_COUNTER = Ref{UInt64}(0)

function next_signal_id()::UInt64
    SIGNAL_ID_COUNTER[] += 1
    return SIGNAL_ID_COUNTER[]
end

# Analysis mode tracking (set by Compiler/Analysis.jl)
const SIGNAL_ANALYSIS_MODE = Ref{Bool}(false)
const ANALYZED_SIGNALS = Ref{Vector{Any}}(Any[])
const SIGNAL_GETTER_MAP = Ref{Dict{Function, UInt64}}(Dict{Function, UInt64}())

# Handler tracing mode - records what operations handlers perform
const HANDLER_TRACING_MODE = Ref{Bool}(false)
const TRACED_OPERATIONS = Ref{Vector{Any}}(Any[])

# Operation types that handlers can perform on signals
@enum SignalOperation begin
    OP_INCREMENT    # signal + 1
    OP_DECREMENT    # signal - 1
    OP_SET          # signal = constant
    OP_ADD          # signal + n
    OP_SUB          # signal - n
    OP_MUL          # signal * n
    OP_NEGATE       # -signal
    OP_TOGGLE       # signal = signal == 0 ? 1 : 0 (boolean toggle)
    OP_UNKNOWN      # couldn't determine operation
end

"""
Represents a traced operation from a handler.
"""
struct TracedOperation
    signal_id::UInt64
    operation::SignalOperation
    operand::Any  # The constant operand for SET, ADD, SUB, MUL
end

"""
Enable handler tracing mode.
"""
function enable_handler_tracing!()
    HANDLER_TRACING_MODE[] = true
    TRACED_OPERATIONS[] = Any[]
end

"""
Disable handler tracing and return traced operations.
"""
function disable_handler_tracing!()
    HANDLER_TRACING_MODE[] = false
    ops = TRACED_OPERATIONS[]
    TRACED_OPERATIONS[] = Any[]
    return ops
end

is_handler_tracing() = HANDLER_TRACING_MODE[]

"""
Record an operation during handler tracing.
"""
function record_traced_operation!(signal_id::UInt64, old_value, new_value)
    op = detect_operation(old_value, new_value)
    push!(TRACED_OPERATIONS[], TracedOperation(signal_id, op.operation, op.operand))
end

"""
Detect what operation was performed based on old and new values.
"""
function detect_operation(old_value::T, new_value::T) where T <: Number
    diff = new_value - old_value

    if diff == 1
        return (operation=OP_INCREMENT, operand=nothing)
    elseif diff == -1
        return (operation=OP_DECREMENT, operand=nothing)
    elseif diff > 0
        return (operation=OP_ADD, operand=diff)
    elseif diff < 0
        return (operation=OP_SUB, operand=-diff)
    elseif old_value != 0 && new_value % old_value == 0
        return (operation=OP_MUL, operand=new_value ÷ old_value)
    elseif new_value == -old_value
        return (operation=OP_NEGATE, operand=nothing)
    else
        return (operation=OP_SET, operand=new_value)
    end
end

function detect_operation(old_value, new_value)
    # For non-numeric types, it's always a SET
    return (operation=OP_SET, operand=new_value)
end

"""
Enable signal analysis mode.
"""
function enable_signal_analysis!()
    SIGNAL_ANALYSIS_MODE[] = true
    ANALYZED_SIGNALS[] = Any[]
    SIGNAL_GETTER_MAP[] = Dict{Function, UInt64}()
end

"""
Disable signal analysis mode and return collected signals.
"""
function disable_signal_analysis!()
    SIGNAL_ANALYSIS_MODE[] = false
    signals = ANALYZED_SIGNALS[]
    getter_map = SIGNAL_GETTER_MAP[]
    ANALYZED_SIGNALS[] = Any[]
    SIGNAL_GETTER_MAP[] = Dict{Function, UInt64}()
    return signals, getter_map
end

"""
Check if we're in signal analysis mode.
"""
is_signal_analysis_mode() = SIGNAL_ANALYSIS_MODE[]

"""
Get the signal ID for a getter function (during analysis).
"""
function get_signal_id_for_getter(getter::Function)
    get(SIGNAL_GETTER_MAP[], getter, nothing)
end

"""
    create_signal(initial::T) -> (getter, setter)

Create a new reactive signal with an initial value.

Returns a tuple of (getter, setter) functions:
- `getter()`: Returns the current value and tracks dependencies
- `setter(value)`: Updates the value and notifies subscribers

# Examples
```julia
count, set_count = create_signal(0)
count()           # => 0
set_count(5)
count()           # => 5
```
"""
function create_signal(initial::T) where T
    signal = Signal{T}(next_signal_id(), initial, Set{Any}())

    # Getter function - reads value and tracks dependency
    getter = function()
        # Track dependency if inside an effect
        effect = current_effect()
        if effect !== nothing
            push!(signal.subscribers, effect)
            # Also register this signal as a dependency of the effect
            push!(effect.dependencies, signal)
        end
        return signal.value
    end

    # Setter function - updates value and notifies
    setter = function(new_value)
        old_value = signal.value

        # Record operation if in handler tracing mode
        if is_handler_tracing()
            record_traced_operation!(signal.id, old_value, new_value)
        end

        if old_value != new_value
            signal.value = new_value
            notify_subscribers!(signal)
        end
        return new_value
    end

    # Record signal if in analysis mode
    if is_signal_analysis_mode()
        push!(ANALYZED_SIGNALS[], (id=signal.id, initial=initial, type=T, getter=getter, setter=setter))
        SIGNAL_GETTER_MAP[][getter] = signal.id
    end

    return (getter, setter)
end

"""
    create_signal(initial::T, transform::Function) -> (getter, setter)

Create a signal with a transform function applied on set.

# Examples
```julia
name, set_name = create_signal("", uppercase)
set_name("hello")
name()  # => "HELLO"
```
"""
function create_signal(initial::T, transform::Function) where T
    signal = Signal{T}(next_signal_id(), transform(initial), Set{Any}())

    getter = function()
        effect = current_effect()
        if effect !== nothing
            push!(signal.subscribers, effect)
            push!(effect.dependencies, signal)
        end
        return signal.value
    end

    setter = function(new_value)
        transformed = transform(new_value)
        if signal.value != transformed
            signal.value = transformed
            notify_subscribers!(signal)
        end
        return transformed
    end

    return (getter, setter)
end

"""
Notify all subscribers that the signal's value has changed.
"""
function notify_subscribers!(signal::Signal)
    for subscriber in signal.subscribers
        if subscriber isa MemoSubscriber
            mark_memo_dirty!(subscriber.memo)
        elseif subscriber isa Effect
            if is_batching()
                queue_update!(subscriber)
            else
                run_effect!(subscriber)
            end
        end
        # TrackingContext and other types are ignored (they're for dependency tracking only)
    end
end

"""
    batch(fn::Function)

Batch multiple signal updates together.
Effects will only run once after all updates complete.

# Examples
```julia
count, set_count = create_signal(0)
name, set_name = create_signal("")

batch() do
    set_count(1)
    set_count(2)
    set_name("hello")
end
# Effects depending on count or name run once here
```
"""
function batch(fn::Function)
    start_batch!()
    try
        fn()
    finally
        end_batch!()
    end
end
