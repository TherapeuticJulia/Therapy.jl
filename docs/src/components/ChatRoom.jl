# ChatRoom.jl - Real-time chat room demo
#
# This component demonstrates Therapy.jl's message channels.
# Unlike signals (continuous state), channels are for discrete
# messages that are delivered but not persisted.

"""
Live chat room demonstrating message channels.

This is NOT an island (no Wasm needed) - it's a static component
that communicates via WebSocket channels. Messages sent through
the channel are:
1. Delivered to all connected clients
2. Not persisted (no message history on reconnect)

In static mode (GitHub Pages), the warning will show that
chat features are unavailable.
"""
function ChatRoom()
    Div(:class => "mb-8",
        :data_ws_example => "true",  # Marks this for static mode warning

        H3(:class => "text-xl font-serif font-semibold text-neutral-900 dark:text-neutral-100 mb-4",
            "Live Chat Room"
        ),

        P(:class => "text-neutral-600 dark:text-neutral-400 mb-4",
            "Send messages to all connected browsers. Messages appear instantly - no page refresh needed!"
        ),

        # Messages container - receives channel messages
        Div(:id => "chat-messages",
            :class => "h-48 overflow-y-auto border border-neutral-300 dark:border-neutral-600 rounded-lg p-4 mb-4 bg-neutral-50 dark:bg-neutral-900 space-y-2",
            :data_channel_messages => "chat",

            # Empty state
            P(:class => "text-neutral-400 dark:text-neutral-500 text-sm italic",
              :id => "chat-empty-state",
              "No messages yet. Be the first to say hello!")
        ),

        # Input area
        Div(:class => "flex gap-2",
            Input(:id => "chat-input",
                  :type => "text",
                  :class => "flex-1 px-4 py-2 border border-neutral-300 dark:border-neutral-600 rounded-lg bg-white dark:bg-neutral-800 text-neutral-900 dark:text-neutral-100 focus:outline-none focus:ring-2 focus:ring-emerald-500",
                  :placeholder => "Type a message...",
                  :onkeydown => "if(event.key==='Enter'){sendChatMessage();event.preventDefault()}"
            ),
            Button(:class => "px-6 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg transition-colors",
                   :onclick => "sendChatMessage()",
                   "Send")
        ),

        # Client-side script for chat functionality
        Script("""
            function sendChatMessage() {
                const input = document.getElementById('chat-input');
                const text = input.value.trim();
                if (text && typeof TherapyWS !== 'undefined' && TherapyWS.isConnected()) {
                    TherapyWS.sendMessage('chat', { text: text });
                    input.value = '';
                }
            }

            // Listen for chat messages
            window.addEventListener('therapy:channel:chat', function(e) {
                const container = document.getElementById('chat-messages');
                const emptyState = document.getElementById('chat-empty-state');
                if (emptyState) emptyState.remove();

                const msg = e.detail;
                const div = document.createElement('div');
                div.className = 'flex items-start gap-2';

                const time = new Date(msg.timestamp * 1000).toLocaleTimeString();
                div.innerHTML = '<span class=\"text-xs text-neutral-400\">' + time + '</span>' +
                    '<span class=\"text-xs text-emerald-600 dark:text-emerald-400 font-mono\">' + msg.from + '</span>' +
                    '<span class=\"text-neutral-900 dark:text-neutral-100\">' + escapeHtml(msg.text) + '</span>';

                container.appendChild(div);
                container.scrollTop = container.scrollHeight;
            });

            function escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }
        """)
    )
end
