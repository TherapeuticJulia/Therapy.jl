# Types.jl - Core reactive type definitions

"""
A reactive signal that holds a value and notifies subscribers when changed.
"""
mutable struct Signal{T}
    id::UInt64
    value::T
    subscribers::Set{Any}
end

"""
An effect that runs a function and tracks signal dependencies.
"""
mutable struct Effect
    id::UInt64
    fn::Function
    dependencies::Set{Any}
    disposed::Bool
end

"""
A memoized computation that caches its value.
"""
mutable struct Memo{T}
    id::UInt64
    fn::Function
    value::T
    dirty::Bool
    dependencies::Set{Any}
    subscribers::Set{Any}
end

"""
Wrapper to distinguish memo subscribers from effect subscribers.
"""
struct MemoSubscriber
    memo::Memo
end

"""
Temporary context for dependency tracking.
"""
mutable struct TrackingContext
    dependencies::Set{Any}
end
