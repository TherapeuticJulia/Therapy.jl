# Memo.jl - Cached computed values

# Global memo ID counter
const MEMO_ID_COUNTER = Ref{UInt64}(0)

function next_memo_id()::UInt64
    MEMO_ID_COUNTER[] += 1
    return MEMO_ID_COUNTER[]
end

"""
    create_memo(fn::Function) -> getter

Create a memoized computation that automatically tracks dependencies
and caches its result.

Returns a getter function that returns the cached value.
The value is only recomputed when dependencies change.

# Examples
```julia
count, set_count = create_signal(0)

# Doubled is a cached computation
doubled = create_memo(() -> count() * 2)

doubled()  # => 0
set_count(5)
doubled()  # => 10 (recomputed because count changed)
doubled()  # => 10 (cached, no recomputation)
```
"""
function create_memo(fn::Function)
    # Compute initial value while tracking dependencies
    dependencies = Set{Any}()
    initial_value = compute_with_tracking(fn, dependencies)

    memo = Memo(
        next_memo_id(),
        fn,
        initial_value,
        false,  # Not dirty initially
        dependencies,
        Set{Any}()
    )

    # Subscribe to all dependencies to mark dirty on change
    for signal in dependencies
        push!(signal.subscribers, MemoSubscriber(memo))
    end

    # Return a getter function
    return function()
        # Track if we're inside an effect
        effect = current_effect()
        if effect !== nothing
            push!(memo.subscribers, effect)
            push!(effect.dependencies, memo)
        end

        # Recompute if dirty
        if memo.dirty
            recompute_memo!(memo)
        end

        return memo.value
    end
end

"""
Compute a function while tracking its dependencies.
"""
function compute_with_tracking(fn::Function, dependencies::Set{Any})
    # Create a temporary effect-like context just for tracking
    tracking_context = TrackingContext(dependencies)
    push_effect_context!(tracking_context)
    try
        return fn()
    finally
        pop_effect_context!()
    end
end

"""
Recompute a memo's value and update dependencies.
"""
function recompute_memo!(memo::Memo)
    # Clear old subscriptions
    for signal in memo.dependencies
        delete!(signal.subscribers, MemoSubscriber(memo))
    end
    empty!(memo.dependencies)

    # Recompute with tracking
    memo.value = compute_with_tracking(memo.fn, memo.dependencies)
    memo.dirty = false

    # Subscribe to new dependencies
    for signal in memo.dependencies
        push!(signal.subscribers, MemoSubscriber(memo))
    end

    # Notify subscribers (effects that depend on this memo)
    for subscriber in memo.subscribers
        if subscriber isa Effect
            if is_batching()
                queue_update!(subscriber)
            else
                run_effect!(subscriber)
            end
        end
    end
end

"""
Mark a memo as dirty (called when a dependency changes).
"""
function mark_memo_dirty!(memo::Memo)
    if !memo.dirty
        memo.dirty = true
        # Propagate to subscribers
        for subscriber in memo.subscribers
            if subscriber isa MemoSubscriber
                mark_memo_dirty!(subscriber.memo)
            end
        end
    end
end

# Extend notify_subscribers! to handle MemoSubscriber
function notify_memo_subscriber!(subscriber::MemoSubscriber)
    mark_memo_dirty!(subscriber.memo)
end
