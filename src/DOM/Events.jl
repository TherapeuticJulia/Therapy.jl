# Events.jl - Event handling

"""
Event types supported by Therapy.jl.
These correspond to DOM event names.
"""
const EVENT_NAMES = Set([
    # Mouse events
    :on_click, :on_dblclick, :on_mousedown, :on_mouseup,
    :on_mouseenter, :on_mouseleave, :on_mousemove, :on_mouseover, :on_mouseout,
    :on_contextmenu,

    # Keyboard events
    :on_keydown, :on_keyup, :on_keypress,

    # Form events
    :on_submit, :on_reset, :on_input, :on_change, :on_focus, :on_blur,
    :on_focusin, :on_focusout,

    # Touch events
    :on_touchstart, :on_touchend, :on_touchmove, :on_touchcancel,

    # Drag events
    :on_drag, :on_dragstart, :on_dragend, :on_dragenter, :on_dragleave,
    :on_dragover, :on_drop,

    # Scroll and resize
    :on_scroll, :on_resize, :on_wheel,

    # Media events
    :on_play, :on_pause, :on_ended, :on_volumechange, :on_timeupdate,
    :on_loadeddata, :on_loadedmetadata, :on_canplay, :on_canplaythrough,

    # Animation events
    :on_animationstart, :on_animationend, :on_animationiteration,
    :on_transitionend,

    # Other
    :on_load, :on_error, :on_copy, :on_cut, :on_paste, :on_select,
])

"""
Check if a prop name is an event handler.
"""
function is_event_prop(name::Symbol)::Bool
    name in EVENT_NAMES
end

"""
Convert Therapy.jl event name to DOM event name.
:on_click -> "click"
"""
function event_name_to_dom(name::Symbol)::String
    str = string(name)
    # Remove "on_" prefix
    if startswith(str, "on_")
        return str[4:end]
    end
    return str
end

"""
Convert DOM event name to Therapy.jl event name.
"click" -> :on_click
"""
function dom_to_event_name(name::String)::Symbol
    Symbol("on_", name)
end
