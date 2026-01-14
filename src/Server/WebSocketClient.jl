# WebSocketClient.jl - Client-side WebSocket JavaScript generation
#
# Generates JavaScript that connects to the Therapy.jl WebSocket server,
# handles reconnection, and updates signals in real-time.

using JSON3
# Note: RawHtml is available from SSR/Render.jl which is included before this file

"""
    websocket_client_script(; signals, reconnect_delay, max_reconnect_delay)

Generate client-side JavaScript for WebSocket connectivity.

# Arguments
- `signals::Vector{String}`: Signal names to auto-subscribe to on connect
- `reconnect_delay::Int`: Initial reconnect delay in ms (default: 1000)
- `max_reconnect_delay::Int`: Maximum reconnect delay in ms (default: 30000)

# Features
- Auto-connects to ws://host/ws on page load
- Exponential backoff reconnection
- Graceful degradation: shows warning on static sites (no server)
- Updates Wasm signals on server updates
- Exposes window.TherapyWS API for programmatic use
"""
function websocket_client_script(;
    signals::Vector{String}=String[],
    reconnect_delay::Int=1000,
    max_reconnect_delay::Int=30000
)
    signals_json = JSON3.write(signals)

    RawHtml("""
<script>
// Therapy.jl WebSocket Client
(function() {
    'use strict';

    const CONFIG = {
        reconnectDelay: $reconnect_delay,
        maxReconnectDelay: $max_reconnect_delay,
        signals: $signals_json
    };

    let ws = null;
    let reconnectAttempts = 0;
    let connectionId = null;
    let isStaticMode = false;

    /**
     * Get WebSocket URL based on current page protocol
     */
    function getWsUrl() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return protocol + '//' + window.location.host + '/ws';
    }

    /**
     * Connect to WebSocket server
     */
    function connect() {
        if (isStaticMode) return;

        try {
            ws = new WebSocket(getWsUrl());

            ws.onopen = function() {
                console.log('[WS] Connected to server');
                reconnectAttempts = 0;

                // Subscribe to configured signals
                CONFIG.signals.forEach(function(sig) {
                    subscribe(sig);
                });

                // Auto-discover and subscribe to signals from data-server-signal attributes
                discoverAndSubscribe();

                // Dispatch connected event
                window.dispatchEvent(new CustomEvent('therapy:ws:connected'));
            };

            ws.onmessage = function(e) {
                try {
                    const msg = JSON.parse(e.data);
                    handleMessage(msg);
                } catch (err) {
                    console.warn('[WS] Failed to parse message:', e.data);
                }
            };

            ws.onclose = function(e) {
                console.log('[WS] Connection closed, code:', e.code);
                connectionId = null;

                // Dispatch disconnected event
                window.dispatchEvent(new CustomEvent('therapy:ws:disconnected'));

                // Attempt reconnect unless it was a clean close
                if (e.code !== 1000) {
                    scheduleReconnect();
                }
            };

            ws.onerror = function(err) {
                console.warn('[WS] Connection error - server may not be running');

                // Check if we're on a static site (GitHub Pages, etc.)
                // Static sites can't accept WebSocket connections
                if (reconnectAttempts === 0) {
                    // First failure - might be static mode
                    setTimeout(function() {
                        if (!ws || ws.readyState !== WebSocket.OPEN) {
                            showStaticModeWarning();
                        }
                    }, 2000);
                }
            };

        } catch (e) {
            console.warn('[WS] Failed to create WebSocket:', e);
            showStaticModeWarning();
        }
    }

    /**
     * Schedule a reconnection attempt with exponential backoff
     */
    function scheduleReconnect() {
        if (isStaticMode) return;

        const delay = Math.min(
            CONFIG.reconnectDelay * Math.pow(2, reconnectAttempts),
            CONFIG.maxReconnectDelay
        );
        reconnectAttempts++;

        console.log('[WS] Reconnecting in', delay, 'ms (attempt', reconnectAttempts + ')');
        setTimeout(connect, delay);
    }

    /**
     * Handle incoming WebSocket message
     */
    function handleMessage(msg) {
        switch (msg.type) {
            case 'connected':
                connectionId = msg.connection_id;
                console.log('[WS] Connection ID:', connectionId);
                break;

            case 'signal_update':
                handleSignalUpdate(msg.signal, msg.value);
                break;

            case 'error':
                console.error('[WS] Server error:', msg.message);
                break;

            case 'pong':
                // Keepalive response, ignore
                break;

            default:
                console.log('[WS] Unknown message type:', msg.type, msg);
        }
    }

    /**
     * Handle a signal update from the server
     */
    function handleSignalUpdate(signalName, value) {
        console.log('[WS] Signal update:', signalName, '=', value);

        // Update via TherapySignals if available (Wasm integration)
        if (window.TherapySignals && window.TherapySignals[signalName]) {
            window.TherapySignals[signalName].set(value);
        }

        // Also update DOM elements with data-server-signal attribute
        document.querySelectorAll('[data-server-signal="' + signalName + '"]').forEach(function(el) {
            if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                el.value = value;
            } else {
                el.textContent = value;
            }
        });

        // Dispatch custom event for custom handlers
        window.dispatchEvent(new CustomEvent('therapy:signal:' + signalName, {
            detail: { value: value }
        }));
    }

    /**
     * Show warning when running in static mode (no WebSocket server)
     */
    function showStaticModeWarning() {
        if (isStaticMode) return;
        isStaticMode = true;

        console.log('[WS] Static mode detected - WebSocket features unavailable');

        // Find all WebSocket example containers and add warning
        document.querySelectorAll('[data-ws-example]').forEach(function(el) {
            if (el.querySelector('.ws-warning')) return;

            const warning = document.createElement('div');
            warning.className = 'ws-warning';
            warning.style.cssText = 'background: linear-gradient(135deg, #fef3c7, #fde68a); border: 1px solid #f59e0b; border-radius: 8px; padding: 16px; margin-bottom: 16px; color: #92400e;';
            warning.innerHTML = '<strong style="display: block; margin-bottom: 4px;">\\u26A0\\uFE0F Live Demo Unavailable</strong>' +
                '<span style="font-size: 14px;">This example requires a WebSocket server. Run locally with:</span>' +
                '<code style="display: block; margin-top: 8px; padding: 8px; background: rgba(0,0,0,0.1); border-radius: 4px; font-family: monospace;">julia docs/app.jl dev</code>';
            el.insertBefore(warning, el.firstChild);
        });

        // Dispatch static mode event
        window.dispatchEvent(new CustomEvent('therapy:ws:static_mode'));
    }

    // Track subscribed signals to avoid duplicates
    let subscribedSignals = new Set();

    /**
     * Subscribe to a server signal
     */
    function subscribe(signalName) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            if (!subscribedSignals.has(signalName)) {
                subscribedSignals.add(signalName);
                ws.send(JSON.stringify({
                    type: 'subscribe',
                    signal: signalName
                }));
            }
        }
    }

    /**
     * Discover and subscribe to signals from data-server-signal attributes
     * Called on connect and after SPA navigation
     */
    function discoverAndSubscribe() {
        document.querySelectorAll('[data-server-signal]').forEach(function(el) {
            var signalName = el.getAttribute('data-server-signal');
            if (signalName && !subscribedSignals.has(signalName)) {
                console.log('[WS] Auto-subscribing to:', signalName);
                subscribe(signalName);
            }
        });
    }

    /**
     * Unsubscribe from a server signal
     */
    function unsubscribe(signalName) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
                type: 'unsubscribe',
                signal: signalName
            }));
        }
    }

    /**
     * Send a custom action to the server
     */
    function sendAction(signalName, action, payload) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
                type: 'action',
                signal: signalName,
                action: action,
                payload: payload
            }));
        }
    }

    /**
     * Send raw message to server
     */
    function send(msg) {
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    }

    /**
     * Check if WebSocket is connected
     */
    function isConnected() {
        return ws && ws.readyState === WebSocket.OPEN;
    }

    /**
     * Get current connection ID
     */
    function getConnectionId() {
        return connectionId;
    }

    /**
     * Manually disconnect
     */
    function disconnect() {
        if (ws) {
            ws.close(1000, 'Client disconnect');
            ws = null;
        }
    }

    // Expose API globally
    window.TherapyWS = {
        connect: connect,
        disconnect: disconnect,
        subscribe: subscribe,
        unsubscribe: unsubscribe,
        discoverAndSubscribe: discoverAndSubscribe,
        sendAction: sendAction,
        send: send,
        isConnected: isConnected,
        getConnectionId: getConnectionId,
        isStaticMode: function() { return isStaticMode; }
    };

    // Auto-connect when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', connect);
    } else {
        connect();
    }
})();
</script>
""")
end
