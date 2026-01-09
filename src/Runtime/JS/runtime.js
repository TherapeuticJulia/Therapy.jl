/**
 * Therapy.jl Client Runtime
 *
 * This runtime connects WebAssembly modules compiled from Julia
 * to the DOM for reactive updates.
 */

class TherapyRuntime {
    constructor() {
        this.instance = null;
        this.elements = new Map();  // hydration key -> DOM element
        this.textNodes = new Map(); // hydration key -> text node for reactive text
    }

    /**
     * Initialize the runtime by scanning the DOM for hydration keys.
     */
    init() {
        // Find all elements with hydration keys
        document.querySelectorAll('[data-hk]').forEach(el => {
            const key = parseInt(el.dataset.hk);
            this.elements.set(key, el);
        });
        console.log(`Therapy: Found ${this.elements.size} hydrated elements`);
    }

    /**
     * Get DOM imports for the Wasm module.
     */
    getImports() {
        const runtime = this;
        return {
            dom: {
                // Get element by hydration key
                get_element: (hk) => {
                    return runtime.elements.get(hk) || null;
                },

                // Set text content of an element
                set_text_content: (hk, text) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.textContent = text;
                },

                // Set inner HTML of an element
                set_inner_html: (hk, html) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.innerHTML = html;
                },

                // Set attribute on an element
                set_attribute: (hk, name, value) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.setAttribute(name, value);
                },

                // Remove attribute from an element
                remove_attribute: (hk, name) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.removeAttribute(name);
                },

                // Add CSS class
                add_class: (hk, className) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.classList.add(className);
                },

                // Remove CSS class
                remove_class: (hk, className) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.classList.remove(className);
                },

                // Toggle CSS class
                toggle_class: (hk, className) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.classList.toggle(className);
                },

                // Set style property
                set_style: (hk, prop, value) => {
                    const el = runtime.elements.get(hk);
                    if (el) el.style[prop] = value;
                },

                // Add event listener (by hydration key)
                add_event_listener: (hk, event, handlerIdx) => {
                    const el = runtime.elements.get(hk);
                    if (el && runtime.instance) {
                        el.addEventListener(event, (e) => {
                            // Call the Wasm handler
                            const handler = runtime.instance.exports[`handler_${handlerIdx}`];
                            if (handler) handler();
                        });
                    }
                },

                // Console logging
                console_log: (msg) => {
                    console.log(msg);
                },

                console_log_i32: (val) => {
                    console.log(val);
                },

                // Alert
                alert: (msg) => {
                    alert(msg);
                },
            },
            env: {
                // Memory (if using linear memory)
                memory: new WebAssembly.Memory({ initial: 1 }),
            }
        };
    }

    /**
     * Load and instantiate a Wasm module.
     */
    async loadWasm(url) {
        try {
            const response = await fetch(url);
            const bytes = await response.arrayBuffer();
            const imports = this.getImports();
            const { instance } = await WebAssembly.instantiate(bytes, imports);
            this.instance = instance;
            console.log('Therapy: Wasm module loaded');

            // Call init if it exists
            if (instance.exports.init) {
                instance.exports.init();
            }

            return instance;
        } catch (e) {
            console.error('Therapy: Failed to load Wasm module', e);
            throw e;
        }
    }

    /**
     * Bind event handlers from the Wasm module to DOM elements.
     * This is called after the module is loaded.
     */
    bindEvents(bindings) {
        // bindings is an array of { hk, event, handler }
        bindings.forEach(({ hk, event, handler }) => {
            const el = this.elements.get(hk);
            if (el) {
                el.addEventListener(event, (e) => {
                    if (typeof handler === 'function') {
                        handler(e);
                    } else if (this.instance && this.instance.exports[handler]) {
                        this.instance.exports[handler]();
                    }
                });
            }
        });
    }

    /**
     * Call an exported Wasm function.
     */
    call(name, ...args) {
        if (this.instance && this.instance.exports[name]) {
            return this.instance.exports[name](...args);
        }
        console.warn(`Therapy: No export named '${name}'`);
    }

    /**
     * Get an exported value (e.g., global).
     */
    get(name) {
        if (this.instance && this.instance.exports[name]) {
            const exp = this.instance.exports[name];
            return typeof exp.value !== 'undefined' ? exp.value : exp;
        }
        return undefined;
    }
}

// Create global instance
window.Therapy = new TherapyRuntime();

// Auto-init when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => window.Therapy.init());
} else {
    window.Therapy.init();
}
