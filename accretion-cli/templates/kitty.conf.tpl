
# Accretion Shell — Kitty

# Font
font_family      Monaspace Argon Frozen
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        11.5
disable_ligatures never

# Colors
background           {{color.bg}}
foreground           {{color.fg}}
selection_background {{color.bgElevated}}
selection_foreground {{color.fg}}

# Window
background_opacity    1
window_padding_width  1
hide_window_decorations yes
draw_minimal_borders no

# Cursor
cursor                 {{color.accentHover}}
cursor_trail           10
cursor_trail_decay     0.1 0.4

# Borders
active_border_color    {{color.accent}}
inactive_border_color  {{color.border}}

# Tab Bar
tab_bar_edge            top
tab_bar_style           powerline
tab_separator           " //"

active_tab_foreground   {{color.fg}}
active_tab_background   {{color.bgElevated}}
inactive_tab_foreground {{color.fgMuted}}
inactive_tab_background {{color.bg}}

# Performance
repaint_delay   10
input_delay     3
sync_to_monitor yes

# Dynamic opacity
dynamic_background_opacity yes
