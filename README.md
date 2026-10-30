# Accretion-shell
> A shell containing a [Quickshell](https://quickshell.outfoxxed.me/) config replacing [Malachite-Quickshell](https://github.com/Bxrnenbaum/Malachite-Quickshell/), a config for rofi, kitty, hyprland, hypridle, hyprlock and hyprpaper aswell as a c# tool for managing themes, dependencies etc.
---

## Screenshots
<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0313f505-06bb-48a9-866f-a750ed56ff3b" />
<img width="1920" height="1080" alt="20261030_14h12m17s_grim" src="https://github.com/user-attachments/assets/043dd4b6-d05b-4921-9bdf-70522cdf0cfc" />

>accretion theme

---

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fcd64f46-d3ac-44f7-b062-ff0dc66812e1" />
<img width="1920" height="1080" alt="20261030_14h14m38s_grim" src="https://github.com/user-attachments/assets/8c3ccc2d-8fe2-443a-a7bf-ed3695a1e980" />

>limbo theme

---

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/d46a17ee-a23c-415a-a3d0-bdc30f11f2fc" />
<img width="1920" height="1080" alt="20261030_14h17m43s_grim" src="https://github.com/user-attachments/assets/42eddfc1-7a18-42fd-a856-307890b921c1" />

>limbo_night theme

---

https://github.com/user-attachments/assets/27adc953-6414-42ef-982a-9cf5c1d9cf48
>theme switching in action. wallr is used in this case, so wallpaper relading is smooth and instant

*All wallpapers have been made using blender*


## Installation
in theory this project should be compatible with Arch, Fedora, NixOS and Opensuse. It is currently only tested on Arch/EndeavourOS (x64).
.NET10.0 is required at the moment to build the project. binaries may come at a later point in time

- run `curl -fsSL https://raw.githubusercontent.com/Bxrnenbaum/accretion-shell/main/scripts/bootstrap.sh | bash`
- add the accretion c# utility to path using `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` (bash only, for zsh for example replace `.bashrc` with `.zshrc`)
- run `accretion install` to install dependencies etc.
- run `accretion config apply` to generate the configs using the colors specified in `~/.local/share/accretion-shell/accretion-cli/theme.json` (you can modify this file to change the colors used in the system)

> if wallr is installed, it will be automatically used, as it provides instant reloading and fading animations, which makes it the preferred alternative to hyprpaper. sadly it isnt available on every distro. replacing hyprpaper with wallr in hyprlandLocal.lua is recommended.


**disclaimer:** accretion-cli does not know your monitor layout our your preference, so it creates a generic hyprlandLocal.lua file. it is strongly recommended to check it and atleast modify the monitor configuration and kb layout to your liking. this file is persistent after updateing using `accretion update` and while not be overwritten once created.
The weather currently defaults to Vienna, modify latitude and longitude in `.config/qs/widgets/WeatherWidget.qml` 

## Usage

#### accretion-cli
accretion-cli is a custom c# application used to install dependencies, update when a new version releases, apply changes to `theme.json` and switch between themes specified in `theme.json`. `accretion uninstall` removes all created symlinks and restores made backups of previous dotfiles, it **does not** delete the repo nor the accretion-cli tool.
Sometimes hyprland throws errors after updating, `hyprctl reload` should fix them.


Theme changes using `accretion config theme <theme_name>` currently dont update instantly, except for programs like quickshell which autoreload. hyprpaper for example has to be restarted manually or by relogging.


#### currently the following keybinds are configured:
- **SUPER + SHIFT + S**: changed to take a region screenshot using hyprshot
- **SUPER + P**: Cycle between dwindle (default) and scrolling layout
- **SUPER + L**: Lock using hyprlock
- **SUPER + K**: run hyprctl kill
- **SUPER + F**: toggle fullscreen
- **SUPER + R**: open rofi menu
- **SUPER + T**: open rofi run menu to run bash commands
- **SUPER + KP_\***: switch to workspaces 11-20
- **SUPER + SHIFT + KP_\***: move a window to workspaces 11-20

aswell as the default hyprland binds, if not overwritten.

## License
This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
