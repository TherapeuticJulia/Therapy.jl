# WasmGen.jl - Generate WebAssembly from component analysis
#
# Uses WasmTarget.jl to compile the reactive logic to Wasm

using WasmTarget
using WasmTarget: WasmModule, add_import!, add_function!, add_export!,
                  add_global!, add_global_export!, to_bytes,
                  I32, I64, F32, F64, ExternRef, Opcode

"""
Result of Wasm generation.
"""
struct WasmOutput
    bytes::Vector{UInt8}
    exports::Vector{String}
    signal_globals::Dict{UInt64, Int}  # signal_id -> global_index
end

"""
    generate_wasm(analysis::ComponentAnalysis) -> WasmOutput

Generate WebAssembly module from component analysis.

The generated module includes:
- Globals for each signal (state)
- Getter/setter functions for each signal
- Handler functions for each event handler
- Imports for DOM manipulation
"""
function generate_wasm(analysis::ComponentAnalysis)
    mod = WasmModule()
    exports = String[]
    signal_globals = Dict{UInt64, Int}()

    # =========================================================================
    # IMPORTS - DOM manipulation functions provided by JS runtime
    # =========================================================================

    # update_text(hk: i32, value: i32) - update text content of element
    add_import!(mod, "dom", "update_text_i32",
                [I32, I32], WasmTarget.NumType[])

    # update_text_f64(hk: i32, value: f64) - update with float
    add_import!(mod, "dom", "update_text_f64",
                [I32, F64], WasmTarget.NumType[])

    # update_attr(hk: i32, attr: i32, value: i32) - update attribute
    add_import!(mod, "dom", "update_attr",
                [I32, I32, I32], WasmTarget.NumType[])

    # set_visible(hk: i32, visible: i32) - show/hide element (0=hidden, 1=visible)
    add_import!(mod, "dom", "set_visible",
                [I32, I32], WasmTarget.NumType[])

    # =========================================================================
    # GLOBALS - One for each signal
    # =========================================================================

    for signal in analysis.signals
        initial = signal.initial_value

        # Determine Wasm type and create global
        if signal.type <: Integer
            global_idx = add_global!(mod, I32, true, Int32(initial))
            signal_globals[signal.id] = global_idx
        elseif signal.type <: AbstractFloat
            global_idx = add_global!(mod, F64, true, Float64(initial))
            signal_globals[signal.id] = global_idx
        else
            # Default to i32 for other types
            global_idx = add_global!(mod, I32, true, Int32(0))
            signal_globals[signal.id] = global_idx
        end

        # Export the global
        add_global_export!(mod, "signal_$(signal.id)", global_idx)
    end

    # =========================================================================
    # SIGNAL GETTERS/SETTERS
    # =========================================================================

    no_params = WasmTarget.NumType[]
    no_results = WasmTarget.NumType[]
    no_locals = WasmTarget.NumType[]

    for signal in analysis.signals
        global_idx = signal_globals[signal.id]

        if signal.type <: Integer
            # get_signal_N() -> i32
            get_code = UInt8[
                Opcode.GLOBAL_GET, UInt8(global_idx),
                Opcode.END
            ]
            get_idx = add_function!(mod, no_params, [I32], no_locals, get_code)
            add_export!(mod, "get_signal_$(signal.id)", 0x00, get_idx)
            push!(exports, "get_signal_$(signal.id)")

            # set_signal_N(value: i32)
            set_code = UInt8[
                Opcode.LOCAL_GET, 0x00,
                Opcode.GLOBAL_SET, UInt8(global_idx),
                Opcode.END
            ]
            set_idx = add_function!(mod, [I32], no_results, no_locals, set_code)
            add_export!(mod, "set_signal_$(signal.id)", 0x00, set_idx)
            push!(exports, "set_signal_$(signal.id)")
        end
    end

    # =========================================================================
    # EVENT HANDLERS - Generated from traced operations
    # =========================================================================

    for handler in analysis.handlers
        handler_code = UInt8[]

        # Track which signals are modified so we can update their DOM bindings
        modified_signals = Set{UInt64}()

        # Generate code for each traced operation
        for op in handler.operations
            if !haskey(signal_globals, op.signal_id)
                continue  # Signal not found, skip
            end

            global_idx = signal_globals[op.signal_id]
            push!(modified_signals, op.signal_id)

            # Generate Wasm code based on operation type
            if op.operation == OP_INCREMENT
                # signal = signal + 1
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.I32_CONST, 0x01,
                    Opcode.I32_ADD,
                    Opcode.GLOBAL_SET, UInt8(global_idx),
                ])
            elseif op.operation == OP_DECREMENT
                # signal = signal - 1
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.I32_CONST, 0x01,
                    Opcode.I32_SUB,
                    Opcode.GLOBAL_SET, UInt8(global_idx),
                ])
            elseif op.operation == OP_ADD
                # signal = signal + n
                append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_signed(Int(op.operand)))
                append!(handler_code, [Opcode.I32_ADD, Opcode.GLOBAL_SET, UInt8(global_idx)])
            elseif op.operation == OP_SUB
                # signal = signal - n
                append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_signed(Int(op.operand)))
                append!(handler_code, [Opcode.I32_SUB, Opcode.GLOBAL_SET, UInt8(global_idx)])
            elseif op.operation == OP_MUL
                # signal = signal * n
                append!(handler_code, [Opcode.GLOBAL_GET, UInt8(global_idx)])
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_signed(Int(op.operand)))
                append!(handler_code, [Opcode.I32_MUL, Opcode.GLOBAL_SET, UInt8(global_idx)])
            elseif op.operation == OP_SET
                # signal = constant
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_signed(Int(op.operand)))
                append!(handler_code, [Opcode.GLOBAL_SET, UInt8(global_idx)])
            elseif op.operation == OP_NEGATE
                # signal = -signal
                append!(handler_code, [
                    Opcode.I32_CONST, 0x00,
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.I32_SUB,
                    Opcode.GLOBAL_SET, UInt8(global_idx),
                ])
            elseif op.operation == OP_TOGGLE
                # signal = (signal == 0) ? 1 : 0
                # i32.eqz returns 1 if value is 0, 0 otherwise
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.I32_EQZ,
                    Opcode.GLOBAL_SET, UInt8(global_idx),
                ])
            end
        end

        # Update DOM for all modified signals
        for signal_id in modified_signals
            global_idx = signal_globals[signal_id]
            bindings_for_signal = filter(b -> b.signal_id == signal_id, analysis.bindings)

            for binding in bindings_for_signal
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_unsigned(binding.target_hk))
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.CALL, 0x00,  # call update_text_i32 (import idx 0)
                ])
            end

            # Update Show visibility for signals that control Show conditions
            shows_for_signal = filter(s -> s.signal_id == signal_id, analysis.show_nodes)
            for show in shows_for_signal
                # set_visible(hk, signal != 0)
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_unsigned(show.target_hk))
                # Convert signal value to bool: (signal != 0) ? 1 : 0
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.I32_CONST, 0x00,
                    Opcode.I32_NE,  # Compare not equal to 0 -> 1 if truthy, 0 if falsy
                    Opcode.CALL, 0x03,  # call set_visible (import idx 3)
                ])
            end
        end

        append!(handler_code, [Opcode.END])

        handler_idx = add_function!(mod, no_params, no_results, no_locals, handler_code)
        add_export!(mod, "handler_$(handler.id)", 0x00, handler_idx)
        push!(exports, "handler_$(handler.id)")
    end

    # =========================================================================
    # INPUT BINDING HANDLERS - Take a value parameter and set signal directly
    # =========================================================================

    for input_binding in analysis.input_bindings
        if !haskey(signal_globals, input_binding.signal_id)
            continue
        end

        global_idx = signal_globals[input_binding.signal_id]

        # Find all bindings that display this signal (to update DOM)
        bindings_for_signal = filter(b -> b.signal_id == input_binding.signal_id, analysis.bindings)

        handler_code = UInt8[]

        # Set the signal from the parameter: signal = param
        append!(handler_code, [
            Opcode.LOCAL_GET, 0x00,  # Get the input value parameter
            Opcode.GLOBAL_SET, UInt8(global_idx),
        ])

        # Update DOM for all bindings (except the input itself which already has the value)
        for binding in bindings_for_signal
            if binding.target_hk != input_binding.target_hk  # Don't update the input itself
                append!(handler_code, [Opcode.I32_CONST])
                append!(handler_code, encode_leb128_unsigned(binding.target_hk))
                append!(handler_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.CALL, 0x00,  # call update_text_i32
                ])
            end
        end

        append!(handler_code, [Opcode.END])

        # Input handlers take one i32 parameter (the new value)
        handler_idx = add_function!(mod, [I32], no_results, no_locals, handler_code)
        add_export!(mod, "input_handler_$(input_binding.handler_id)", 0x00, handler_idx)
        push!(exports, "input_handler_$(input_binding.handler_id)")
    end

    # =========================================================================
    # INIT FUNCTION - Called after hydration to sync initial state
    # =========================================================================

    init_code = UInt8[]
    for signal in analysis.signals
        if signal.type <: Integer
            global_idx = signal_globals[signal.id]
            bindings_for_signal = filter(b -> b.signal_id == signal.id, analysis.bindings)

            for binding in bindings_for_signal
                append!(init_code, [
                    Opcode.I32_CONST
                ])
                append!(init_code, encode_leb128_unsigned(binding.target_hk))
                append!(init_code, [
                    Opcode.GLOBAL_GET, UInt8(global_idx),
                    Opcode.CALL, 0x00,  # call update_text_i32
                ])
            end
        end
    end
    append!(init_code, [Opcode.END])

    if !isempty(init_code)
        init_idx = add_function!(mod, no_params, no_results, no_locals, init_code)
        add_export!(mod, "init", 0x00, init_idx)
        push!(exports, "init")
    end

    return WasmOutput(to_bytes(mod), exports, signal_globals)
end

"""
Encode unsigned LEB128 integer.
"""
function encode_leb128_unsigned(value::Int)::Vector{UInt8}
    result = UInt8[]
    while true
        byte = UInt8(value & 0x7f)
        value >>= 7
        if value != 0
            byte |= 0x80
        end
        push!(result, byte)
        if value == 0
            break
        end
    end
    return result
end

"""
Encode signed LEB128 integer.
"""
function encode_leb128_signed(value::Int)::Vector{UInt8}
    result = UInt8[]
    more = true
    while more
        byte = UInt8(value & 0x7f)
        value >>= 7
        # Check if we need more bytes
        if (value == 0 && (byte & 0x40) == 0) || (value == -1 && (byte & 0x40) != 0)
            more = false
        else
            byte |= 0x80
        end
        push!(result, byte)
    end
    return result
end
