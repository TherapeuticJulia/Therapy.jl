# TicTacToe Tutorial Implementation Plan

## Goal
Create a Therapy.jl tutorial that mirrors React's TicTacToe tutorial structure, with winner checking done entirely in Julia/Wasm (not JavaScript).

## React Tutorial Structure → Therapy.jl Mapping

### React Concepts → Therapy.jl Equivalents

| React Concept | Therapy.jl Equivalent | Status |
|---------------|----------------------|--------|
| `function Square()` component | `function Square()` Julia function | WORKS |
| `function Board()` component | `function Board()` Julia function | WORKS |
| JSX `<button className="...">` | `Button(:class => "...")` | WORKS |
| `useState(null)` | `create_signal(0)` | WORKS |
| Props `{ value, onSquareClick }` | Function arguments | WORKS |
| `onClick={handleClick}` | `:on_click => handler` | WORKS |
| `if (squares[i]) return` | `if s0() != 0 ... end` | **BROKEN** |
| `squares[i] = 'X'` | `set_s0(1)` | WORKS |
| `xIsNext ? 'X' : 'O'` | `turn() == 0 ? 1 : 2` | WORKS |
| `calculateWinner(squares)` | `calculate_winner(...)` in Julia | **BROKEN** |
| `status = winner ? "Winner: " + winner : "Next: " + player` | Computed display | **BROKEN** |
| `history.map(...)` for time travel | Vector signals (FUTURE) | NOT STARTED |

### What's Currently Working

1. **Basic Signals**: `count, set_count = create_signal(0)` → Wasm globals
2. **Simple Handlers**: `() -> set_count(count() + 1)` → Wasm functions
3. **Simple Conditionals**: `if s0() == 0 ... end` → Wasm if/else
4. **Ternary Expressions**: `a ? b : c` → Wasm select/if
5. **DOM Updates**: Auto-injected `update_text(hk, value)` calls

### What's Broken (Preventing Winner Checking in Julia)

#### Issue 1: `&&` Short-Circuit in Void Handlers

The winner check requires:
```julia
if s0() != 0 && s0() == s1() && s0() == s2()
    # winner found
end
```

Julia compiles `a && b && c` into nested GotoIfNot:
```
%1 = s0() != 0
     GotoIfNot %1 → label_end
%2 = s0() == s1()
     GotoIfNot %2 → label_end
%3 = s0() == s2()
     GotoIfNot %3 → label_end
     # then branch
label_end:
```

**Current Problem**: `generate_void_flow` in Codegen.jl line 1823-1825 calls `compile_ternary_for_phi` for nested GotoIfNot, which expects a phi node pattern. For void handlers, there's no phi, so stack gets corrupted.

#### Issue 2: Multiple Consecutive Conditionals

Winner checking has 8 sequential if-blocks:
```julia
if row0_wins return 1 end
if row1_wins return 1 end
if row2_wins return 1 end
# ... etc
```

**Current Problem**: `generate_void_flow` handles ONE conditional, but multiple sequential conditionals each leave values on the stack or don't properly structure the blocks.

#### Issue 3: Early Returns in Conditionals

React pattern:
```javascript
function handleClick(i) {
    if (calculateWinner(squares) || squares[i]) {
        return; // early return
    }
    // continue with move
}
```

Julia equivalent:
```julia
function handler()
    if winner != 0 || s0() != 0
        return nothing
    end
    # make move
end
```

**Current Problem**: Early returns in void handlers may leave stack in wrong state.

#### Issue 4: Calling Helper Functions

React has `calculateWinner(squares)` as a separate function. In Therapy.jl:
```julia
function calculate_winner(s0, s1, s2, s3, s4, s5, s6, s7, s8)
    # check all 8 lines
    if s0() != 0 && s0() == s1() && s0() == s2()
        return s0()
    end
    # ...
    return 0
end
```

**Current Problem**: `compile_multi` can handle multiple functions, but handler closures that capture signals and call other functions need the signal substitution to work correctly in both the closure and the called function.

---

## Required WasmTarget.jl Fixes

### Fix 1: Recursive Void Flow for Nested Conditionals

**File**: `src/Compiler/Codegen.jl`
**Function**: `generate_void_flow`

Current code at line 1823-1825:
```julia
elseif inner isa Core.GotoIfNot
    # Nested conditional - compile inner ternary
    append!(bytes, compile_ternary_for_phi(ctx, code, j, compiled))
```

**Fix**: Replace with recursive void conditional handling:
```julia
elseif inner isa Core.GotoIfNot
    # Nested conditional in void context - recurse
    append!(bytes, compile_void_conditional(ctx, code, j, compiled))
```

New function needed:
```julia
function compile_void_conditional(ctx, code, start_idx, compiled)
    bytes = UInt8[]
    goto_if_not = code[start_idx]
    else_target = goto_if_not.dest

    # Push condition
    append!(bytes, compile_value(goto_if_not.cond, ctx))
    push!(compiled, start_idx)

    # Start void if block
    push!(bytes, Opcode.IF)
    push!(bytes, 0x40)

    # Compile then-branch, recursively handling nested conditions
    for j in (start_idx+1):(else_target-1)
        if j in compiled
            continue
        end
        inner = code[j]
        if inner isa Core.GotoIfNot
            # RECURSION for nested &&
            append!(bytes, compile_void_conditional(ctx, code, j, compiled))
        elseif inner isa Core.ReturnNode
            # Early return in void handler
            push!(bytes, Opcode.RETURN)
            push!(compiled, j)
        elseif inner === nothing || inner isa Core.GotoNode
            push!(compiled, j)
        else
            append!(bytes, compile_statement(inner, j, ctx))
            push!(compiled, j)
            # Drop unused values in void context
            maybe_drop_unused_value!(bytes, ctx, j)
        end
    end

    # End if (no else in && pattern)
    push!(bytes, Opcode.END)

    # Mark range as compiled
    for j in start_idx:(else_target-1)
        push!(compiled, j)
    end

    return bytes
end
```

### Fix 2: Proper Stack Management for Void Returns

**File**: `src/Compiler/Codegen.jl`

When a void handler has early returns, ensure stack is clean:
```julia
function compile_void_return(ctx)::Vector{UInt8}
    bytes = UInt8[]
    # In void context, just return - stack should already be empty
    # If there's a value on stack (from an expression), drop it first
    push!(bytes, Opcode.RETURN)
    return bytes
end
```

### Fix 3: Sequential Void Conditionals

Multiple if-blocks in sequence:
```julia
if check1() ... end
if check2() ... end
if check3() ... end
```

Each should compile to independent if-blocks with their own stack scope:
```wasm
;; check 1
condition1
if
  ;; then1
end
;; check 2
condition2
if
  ;; then2
end
;; etc
```

The current code handles this but may not properly reset compiled set. Need to ensure each conditional is handled independently.

---

## Required Therapy.jl Changes

### Change 1: Winner Signal and Status Display

Add a winner signal that's computed after each move:
```julia
function TicTacToe()
    # Board signals
    s0, set_s0 = create_signal(0)
    # ... s1-s8

    # Game state
    turn, set_turn = create_signal(0)
    winner, set_winner = create_signal(0)  # 0=none, 1=X, 2=O

    # Handler that includes winner check
    function make_move(square_getter, square_setter, idx)
        () -> begin
            if winner() != 0  # Game already over
                return nothing
            end
            if square_getter() != 0  # Square taken
                return nothing
            end
            # Make move
            square_setter(turn() == 0 ? 1 : 2)
            set_turn(turn() == 0 ? 1 : 0)
            # Check winner
            w = calculate_winner(s0, s1, s2, s3, s4, s5, s6, s7, s8)
            set_winner(w)
        end
    end

    # UI with conditional status
    Div(
        # Status: show winner or next player
        Div(
            Show(() -> winner() != 0) do
                Span("Winner: ", winner() == 1 ? "X" : "O")
            end,
            Show(() -> winner() == 0) do
                Span("Next: ", turn() == 0 ? "X" : "O")
            end
        ),
        # Board
        # ...
    )
end

function calculate_winner(s0, s1, s2, s3, s4, s5, s6, s7, s8)
    # Check rows
    if s0() != 0 && s0() == s1() && s0() == s2()
        return s0()
    end
    if s3() != 0 && s3() == s4() && s3() == s5()
        return s3()
    end
    if s6() != 0 && s6() == s7() && s6() == s8()
        return s6()
    end
    # Check columns
    if s0() != 0 && s0() == s3() && s0() == s6()
        return s0()
    end
    if s1() != 0 && s1() == s4() && s1() == s7()
        return s1()
    end
    if s2() != 0 && s2() == s5() && s2() == s8()
        return s2()
    end
    # Check diagonals
    if s0() != 0 && s0() == s4() && s0() == s8()
        return s0()
    end
    if s2() != 0 && s2() == s4() && s2() == s6()
        return s2()
    end
    return 0
end
```

### Change 2: Compile Helper Functions with Handlers

When compiling handlers, also compile helper functions they call:
```julia
# In WasmGen.jl
function generate_wasm(analysis::ComponentAnalysis)
    # Collect all functions needed
    functions_to_compile = []

    # Add handlers
    for handler in analysis.handlers
        push!(functions_to_compile, (handler.closure, handler_arg_types))
    end

    # Add helper functions referenced by handlers
    for helper in analysis.helper_functions
        push!(functions_to_compile, (helper.func, helper.arg_types))
    end

    # Compile all together
    bytes = compile_multi(functions_to_compile, ...)
end
```

---

## Tutorial Structure (Matching React)

### Part 1: Setup
- Install Therapy.jl
- Create project structure
- Explain: component = Julia function

### Part 2: Building the Board
- Start with static HTML equivalent
- Create `Square` function
- Create `Board` function with 9 squares
- Style with Tailwind CSS

### Part 3: Adding Interactivity
- Introduce `create_signal`
- Make square clickable (shows X)
- Explain: signal = reactive state

### Part 4: Lifting State Up
- Move state to Board
- Pass signal to Square as prop
- Handle click in Board

### Part 5: Taking Turns
- Add turn signal
- Alternate X and O
- Prevent overwriting

### Part 6: Declaring a Winner
- Create `calculate_winner` function (PURE JULIA)
- Add winner signal
- Display winner status
- Block moves after win

### Part 7: Time Travel (FUTURE)
- History as Vector of states
- Jump to previous move
- Requires: Vector signals, For construct

---

## Implementation Priority

### Phase 1: Fix WasmTarget Compiler (CRITICAL)
1. Fix nested GotoIfNot in void handlers
2. Fix sequential void conditionals
3. Add tests for complex control flow

### Phase 2: Add Winner Checking to TicTacToe
1. Remove JS checkWinner function
2. Add calculate_winner in Julia
3. Add winner signal
4. Update handlers to check winner

### Phase 3: Write Tutorial
1. Mirror React tutorial structure
2. Interactive code examples
3. Explain Julia/Wasm compilation

### Phase 4: Future Features
1. Array/Vector signals for history
2. `For` construct for dynamic lists
3. Time travel feature

---

## Test Cases for Compiler Fixes

```julia
# Test 1: Simple && in void handler
function test_and_void()
    g = WasmGlobal{Int32, 0}
    if g[] != Int32(0) && g[] == Int32(1)
        g[] = Int32(99)
    end
    return nothing
end

# Test 2: Multiple sequential ifs in void handler
function test_multi_if_void()
    g = WasmGlobal{Int32, 0}
    if g[] == Int32(1)
        g[] = Int32(10)
    end
    if g[] == Int32(2)
        g[] = Int32(20)
    end
    return nothing
end

# Test 3: Early return in void handler
function test_early_return_void()
    g = WasmGlobal{Int32, 0}
    if g[] != Int32(0)
        return nothing
    end
    g[] = Int32(1)
    return nothing
end

# Test 4: Nested && with function calls (winner pattern)
function test_winner_pattern()
    s0 = WasmGlobal{Int32, 0}
    s1 = WasmGlobal{Int32, 1}
    s2 = WasmGlobal{Int32, 2}
    result = WasmGlobal{Int32, 3}

    if s0[] != Int32(0) && s0[] == s1[] && s0[] == s2[]
        result[] = s0[]
    end
    return nothing
end
```

---

## Summary

**The core issue**: WasmTarget's `generate_void_flow` can't handle nested GotoIfNot patterns from `&&` operators. This prevents implementing `calculate_winner` in pure Julia.

**The fix**: Add recursive handling of void conditionals that properly nests Wasm if-blocks without leaving values on the stack.

**Once fixed**: TicTacToe can have winner checking entirely in Julia/Wasm, matching the React tutorial's approach where `calculateWinner` is a pure JavaScript helper function.
