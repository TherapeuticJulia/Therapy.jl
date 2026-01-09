# Effect.jl - Side effects that re-run when dependencies change

# Global effect ID counter
const EFFECT_ID_COUNTER = Ref{UInt64}(0)

function next_effect_id()::UInt64
    EFFECT_ID_COUNTER[] += 1
    return EFFECT_ID_COUNTER[]
end

"""
    create_effect(fn::Function) -> Effect

Create a reactive effect that runs immediately and re-runs whenever
any signal it reads changes.

# Examples
```julia
count, set_count = create_signal(0)

# This runs immediately and again whenever count() changes
create_effect() do
    println("Count is: ", count())
end

set_count(5)  # Prints: "Count is: 5"
```
"""
function create_effect(fn::Function)
    effect = Effect(next_effect_id(), fn, Set{Any}(), false)

    # Run immediately to establish dependencies
    run_effect!(effect)

    return effect
end

"""
Run an effect, tracking its dependencies.
"""
function run_effect!(effect::Effect)
    if effect.disposed
        return
    end

    # Clear old dependencies
    cleanup_effect!(effect)

    # Push onto effect stack so signals can register as dependencies
    push_effect_context!(effect)

    try
        effect.fn()
    finally
        pop_effect_context!()
    end
end

"""
Clean up an effect's dependencies.
"""
function cleanup_effect!(effect::Effect)
    # Remove this effect from all signals it was subscribed to
    for signal in effect.dependencies
        delete!(signal.subscribers, effect)
    end
    empty!(effect.dependencies)
end

"""
    dispose!(effect::Effect)

Stop an effect from running again and clean up its dependencies.

# Examples
```julia
count, set_count = create_signal(0)

effect = create_effect() do
    println("Count: ", count())
end

dispose!(effect)
set_count(5)  # No output - effect is disposed
```
"""
function dispose!(effect::Effect)
    effect.disposed = true
    cleanup_effect!(effect)
end
