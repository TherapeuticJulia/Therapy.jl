# Context.jl - Dependency tracking context for reactivity

"""
Global context for tracking which effect is currently running.
This enables automatic dependency tracking when signals are read.
"""
const EFFECT_STACK = Any[]

"""
Batch mode flag and pending updates queue.
When batching, signal updates are queued instead of immediately triggering effects.
"""
const BATCH_MODE = Ref(false)
const PENDING_UPDATES = Set{Any}()

"""
Push an effect onto the tracking stack.
Called when an effect starts running.
"""
function push_effect_context!(effect)
    push!(EFFECT_STACK, effect)
end

"""
Pop the current effect from the tracking stack.
Called when an effect finishes running.
"""
function pop_effect_context!()
    pop!(EFFECT_STACK)
end

"""
Get the currently running effect, or nothing if none.
"""
function current_effect()
    isempty(EFFECT_STACK) ? nothing : last(EFFECT_STACK)
end

"""
Check if we're currently inside an effect context.
"""
function in_effect_context()::Bool
    !isempty(EFFECT_STACK)
end

"""
Start batch mode - updates will be queued.
"""
function start_batch!()
    BATCH_MODE[] = true
end

"""
End batch mode - run all queued updates.
"""
function end_batch!()
    BATCH_MODE[] = false
    # Run all pending effects
    for effect in PENDING_UPDATES
        run_effect!(effect)
    end
    empty!(PENDING_UPDATES)
end

"""
Check if we're in batch mode.
"""
function is_batching()::Bool
    BATCH_MODE[]
end

"""
Queue an effect to run after batch completes.
"""
function queue_update!(effect)
    push!(PENDING_UPDATES, effect)
end
