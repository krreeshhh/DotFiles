-- -----------------------------------------------------
-- Hypr PiP - Hyprland Window Rules (Lua format)
-- -----------------------------------------------------
-- Automatically floats, pins, sizes, and positions Picture-in-Picture windows.
-- Follows the user across all Hyprland workspaces.

-- Universal PiP window rule (Chromium, Chrome, Brave, Helium, Edge, etc.)
hl.window_rule({
    name = "pip-universal-floating",
    match = {
        title = "^(Picture[- ]in[- ][Pp]icture|Picture in picture)$",
    },
    float = true,
    pin = true,
    size = "480 270",
    move = "100%-500 100%-290",
    keep_aspect_ratio = true,
})

-- Firefox / Floorp / Zen Browser PiP rule
hl.window_rule({
    name = "pip-firefox-floating",
    match = {
        class = "^(firefox.*|floorp|zen.*)$",
        title = "^(Picture-in-Picture)$",
    },
    float = true,
    pin = true,
    size = "480 270",
    move = "100%-500 100%-290",
    keep_aspect_ratio = true,
})

-- Chromium / Brave / Helium PiP rule
hl.window_rule({
    name = "pip-chromium-floating",
    match = {
        class = "^(brave.*|helium.*|google-chrome.*|chromium.*)$",
        title = "^(Picture[- ]in[- ][Pp]icture|Picture in picture)$",
    },
    float = true,
    pin = true,
    size = "480 270",
    move = "100%-500 100%-290",
    keep_aspect_ratio = true,
})
