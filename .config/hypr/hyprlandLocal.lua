local T = require("HyprlandTheme")

return {
	apps = {
		terminal = "kitty",
		fileManager = "nautilus",
		menu = "rofi -show drun",
		menuRun = "rofi -show run",
		menuMode = "rofi -show combi -combi-modes 'drun,script:~/.config/hypr/app-groups.sh' -modes 'combi' -combi-hide-mode-prefix",
	},

	monitors = {
		{ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1.25 },
		{ output = "HDMI-A-1", mode = "preferred", position = "1920x0", scale = 1.25 },
	},

	workspaceMonitor = "DP-2",
	screenshotOutput = "eDP-1",

	autostart = {
		"qs --path /mnt/Data/github/accretion-shell/.config/qs/",
		"swaync",
		"/usr/lib/polkit-kde-authentication-agent-1",
		"hypridle",
		"wl-paste --type text --watch cliphist store",
		"wl-paste --image --watch cliphist store",
		"~/sh_scripts/switch_config_fastfetch.sh",
		"~/sh_scripts/switch_config_kitty.sh",
		"~/sh_scripts/switch_config_firefox.sh",
		"hyprpm reload -n",
		"$HOME/.config/hypr/wallpaper-pause.sh",
		'mpvpaper -o "no-audio loop video-crop=2560x1440+0+0 video-sync=display-sample hwdec=auto input-ipc-server=/tmp/mpvpaper.sock speed=1.0" ALL $HOME/.config/hypr/videos/0001-0900.mp4',
	},

	env = {
		GTK_THEME = "oomox-vortex2",
		XCURSOR_SIZE = "20",
		HYPRCURSOR_SIZE = "20",
		GDK_SCALE = "1",
		WINE_FULLSCREEN_INTEGER_SCALING = "1",
	},

	config = {
		general = {
			gaps_in = 5,
			gaps_out = 8,
			border_size = T.borderSize,
			col = {
				active_border = { colors = { T.colors.fg, T.colors.warning }, angle = T.borderGradientAngle },
				inactive_border = { colors = { T.colors.border, T.colors.bg }, angle = T.borderGradientAngle },
			},
			resize_on_border = true,
			allow_tearing = false,
			layout = "dwindle",
		},
		decoration = {
			rounding = T.rounding,
			rounding_power = T.roundingPower,
			active_opacity = 1.0,
			inactive_opacity = 1.0,
			shadow = {
				enabled = true,
				range = 15,
				render_power = 3,
				color = T.shadowColor,
			},
			blur = {
				enabled = false,
				size = 3,
				passes = 2,
				vibrancy = 0.1696,
			},
		},
		dwindle = { preserve_split = true },
		master = { new_status = "master" },
		scrolling = {
			fullscreen_on_one_column = true,
			column_width = 0.96,
			focus_fit_method = 0,
			direction = "down",
		},
		misc = {
			force_default_wallpaper = 0,
			disable_hyprland_logo = true,
			disable_splash_rendering = true,
		},
		xwayland = { force_zero_scaling = true },
		input = {
			kb_layout = "de",
			kb_variant = "nodeadkeys",
			follow_mouse = 1,
			sensitivity = -0.35,
			force_no_accel = true,
			touchpad = { natural_scroll = true },
		},
	},

	devices = {
		{ name = "epic-mouse-v1", sensitivity = -0.5 },
	},

	hyprexpo = {
		columns = 3,
		gaps_in = 8,
		gaps_out = 16,
		bg_col = T.colors.bgSecondary,
		workspace_method = "first 1",
	},

	curves = {
		fluent_decel = { type = "bezier", points = { { 0, 0.2 }, { 0.4, 1 } } },
		easeOutCubic = { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } },
		easeinoutsine = { type = "bezier", points = { { 0.37, 0 }, { 0.63, 1 } } },
	},

	animations = {
		{ leaf = "windowsIn", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefadevert 30%" },
		{ leaf = "windowsOut", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefadevert 30%" },
		{ leaf = "windowsMove", enabled = true, speed = 2, bezier = "fluent_decel", style = "slidefadevert 30%" },
		{ leaf = "fade", enabled = true, speed = 3, bezier = "fluent_decel" },
		{ leaf = "fadeLayersIn", enabled = false },
		{ leaf = "fadeLayersOut", enabled = false },
		{ leaf = "border", enabled = false },
		{ leaf = "layers", enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefadevert 30%" },
		{ leaf = "workspaces", enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefade 30%" },
		{ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "fluent_decel", style = "slidefade 30%" },
	},

	windowRules = {
		{
			name = "move-hyprland-run",
			match = { class = "hyprland-run" },
			move = "20 monitor_h-120",
			float = true,
		},
		{
			name = "slayThespire",
			match = { class = "^(Slay the Spire)$" },
			fullscreen = true,
			float = true,
		},
		{
			name = "gnome-calculator-min-size",
			match = { class = "org.gnome.Calculator" },
			float = true,
			size = "300 400",
		},
	},

	layerRules = {
		{
			match = { namespace = "^quickshell-bar$" },
			blur = true,
			ignore_alpha = 0.1,
			xray = true,
		},
	},
}
