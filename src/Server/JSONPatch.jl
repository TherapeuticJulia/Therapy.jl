# JSONPatch.jl - RFC 6902 JSON Patch implementation
#
# Computes diffs between old and new values, and applies patches.
# Used by WebSocket to send efficient updates (diffs instead of full values).

"""
    compute_patch(old_value, new_value) -> Vector{Dict{String,Any}}

Compute a JSON patch (RFC 6902) between old and new values.
Returns a Vector of patch operations.

Supported operations: add, remove, replace
(move, copy, test are not implemented for MVP)

# Examples
```julia
# Simple value change
compute_patch(1, 2)  # [Dict("op" => "replace", "path" => "", "value" => 2)]

# Dict changes
compute_patch(Dict("a" => 1), Dict("a" => 2, "b" => 3))
# [Dict("op" => "replace", "path" => "/a", "value" => 2),
#  Dict("op" => "add", "path" => "/b", "value" => 3)]
```
"""
function compute_patch(old_value, new_value)::Vector{Dict{String,Any}}
    patches = Dict{String,Any}[]

    # Handle nil/nothing values
    if old_value === nothing && new_value === nothing
        return patches
    elseif old_value === nothing
        push!(patches, Dict("op" => "replace", "path" => "", "value" => new_value))
        return patches
    elseif new_value === nothing
        push!(patches, Dict("op" => "replace", "path" => "", "value" => nothing))
        return patches
    end

    # Simple values (not Dict or Vector) - just replace if different
    if !(old_value isa Dict || old_value isa AbstractVector) ||
       !(new_value isa Dict || new_value isa AbstractVector)
        if old_value != new_value
            push!(patches, Dict("op" => "replace", "path" => "", "value" => new_value))
        end
        return patches
    end

    # Both are Dicts - compute key differences
    if old_value isa Dict && new_value isa Dict
        # Added or changed keys
        for (k, v) in new_value
            k_str = string(k)
            if !haskey(old_value, k)
                push!(patches, Dict("op" => "add", "path" => "/$k_str", "value" => v))
            elseif old_value[k] != v
                # Recursively compute patches for nested values
                if (old_value[k] isa Dict && v isa Dict) || (old_value[k] isa AbstractVector && v isa AbstractVector)
                    nested_patches = compute_patch(old_value[k], v)
                    for np in nested_patches
                        # Prepend our path to nested patch path
                        np["path"] = "/$k_str" * np["path"]
                        push!(patches, np)
                    end
                else
                    push!(patches, Dict("op" => "replace", "path" => "/$k_str", "value" => v))
                end
            end
        end
        # Removed keys
        for k in keys(old_value)
            k_str = string(k)
            if !haskey(new_value, k)
                push!(patches, Dict("op" => "remove", "path" => "/$k_str"))
            end
        end
        return patches
    end

    # Both are Vectors - for MVP, just replace if different
    # (Computing minimal array diffs is complex; LCS-based algorithms are O(n²))
    if old_value != new_value
        push!(patches, Dict("op" => "replace", "path" => "", "value" => new_value))
    end
    return patches
end

"""
    apply_patch(value, patch::Vector) -> Any

Apply a JSON patch (RFC 6902) to a value.
Returns the new value after applying all operations.

# Examples
```julia
value = Dict("a" => 1)
patch = [Dict("op" => "add", "path" => "/b", "value" => 2)]
apply_patch(value, patch)  # Dict("a" => 1, "b" => 2)
```
"""
function apply_patch(value, patch::Vector)
    result = deepcopy(value)
    for op in patch
        result = apply_operation(result, op)
    end
    return result
end

"""
    apply_operation(value, op::Dict) -> Any

Apply a single JSON patch operation.
"""
function apply_operation(value, op::Dict)
    operation = get(op, "op", "")
    path = get(op, "path", "")

    # Root replacement
    if path == ""
        return get(op, "value", nothing)
    end

    # Parse path (e.g., "/users/0/name" -> ["users", "0", "name"])
    parts = split(path, "/")
    # Skip empty first element from leading /
    parts = filter(!isempty, parts)

    if operation == "replace" || operation == "add"
        set_at_path!(value, parts, op["value"])
    elseif operation == "remove"
        remove_at_path!(value, parts)
    end

    return value
end

"""
    set_at_path!(value, path_parts::Vector, new_value)

Set a value at a nested path, creating intermediate containers as needed.
"""
function set_at_path!(value, path_parts::AbstractVector, new_value)
    if isempty(path_parts)
        return new_value
    end

    current = value
    for (i, part) in enumerate(path_parts[1:end-1])
        if current isa Dict
            if !haskey(current, part)
                # Create intermediate Dict
                current[part] = Dict{String,Any}()
            end
            current = current[part]
        elseif current isa AbstractVector
            idx = parse(Int, part) + 1  # JSON arrays are 0-indexed
            current = current[idx]
        else
            error("Cannot traverse path through $(typeof(current))")
        end
    end

    # Set the final value
    final_part = path_parts[end]
    if current isa Dict
        current[final_part] = new_value
    elseif current isa AbstractVector
        idx = parse(Int, final_part) + 1
        if final_part == "-" || idx > length(current)
            push!(current, new_value)
        else
            current[idx] = new_value
        end
    end

    return value
end

"""
    remove_at_path!(value, path_parts::Vector)

Remove a value at a nested path.
"""
function remove_at_path!(value, path_parts::AbstractVector)
    if isempty(path_parts)
        return nothing
    end

    current = value
    for part in path_parts[1:end-1]
        if current isa Dict
            current = get(current, part, nothing)
        elseif current isa AbstractVector
            idx = parse(Int, part) + 1
            current = current[idx]
        else
            return value  # Path doesn't exist
        end
        current === nothing && return value
    end

    # Remove the final element
    final_part = path_parts[end]
    if current isa Dict
        delete!(current, final_part)
    elseif current isa AbstractVector
        idx = parse(Int, final_part) + 1
        deleteat!(current, idx)
    end

    return value
end
