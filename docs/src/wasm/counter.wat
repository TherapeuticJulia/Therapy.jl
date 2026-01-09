;; counter.wat - Simple counter WebAssembly module for docs demo
;;
;; This is hand-written WAT to demonstrate the hydration concept.
;; In real usage, Therapy.jl compiles Julia handlers to similar Wasm.

(module
  ;; Import DOM update function from JavaScript
  (import "dom" "update_text" (func $update_text (param i32)))

  ;; Global counter state
  (global $count (mut i32) (i32.const 0))

  ;; Increment handler - called when + button clicked
  (func (export "increment")
    ;; count = count + 1
    global.get $count
    i32.const 1
    i32.add
    global.set $count

    ;; Update DOM with new value
    global.get $count
    call $update_text
  )

  ;; Decrement handler - called when - button clicked
  (func (export "decrement")
    ;; count = count - 1
    global.get $count
    i32.const 1
    i32.sub
    global.set $count

    ;; Update DOM with new value
    global.get $count
    call $update_text
  )
)
