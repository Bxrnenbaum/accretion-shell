# Accretion-shell
> A shell containing a [Quickshell](https://quickshell.outfoxxed.me/) config replacing [Malachite-Quickshell](https://github.com/Bxrnenbaum/Malachite-Quickshell/), a config for rofi, hyprland, hypridle, hyprlock and hyprpaper.
---

## Screenshots
<img width="1920" height="1080" alt="accretion desktop" src="https://github.com/user-attachments/assets/f4ab3cc9-e431-4df3-8a4d-9439e0bc7797" />
<img width="1920" height="1080" alt="accretion lockscreen" src="https://github.com/user-attachments/assets/c91e8430-72ca-42bf-87d4-62e9ed8562a0" />

>accretion theme

---

<img width="1920" height="1080" alt="limbo desktop" src="https://github.com/user-attachments/assets/6808a03d-1f68-4f9c-a0f6-9019d0f646ad" />
<img width="1920" height="1080" alt="limbo lockscreen" src="https://github.com/user-attachments/assets/b63599b0-fef2-465e-9d27-f7e9b3190756" />

>limbo theme

## Installation
in theory this project should be compatible with Arch, Fedora, NixOS and Opensuse.It is currently only tested on Arch/EndeavourOS.

- run `curl -fsSL https://raw.githubusercontent.com/Bxrnenbaum/accretion-shell/main/scripts/bootstrap.sh | bash`
- add the accretion c# utility to path using `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` (bash only, for zsh for example replace `.bashrc` with `.zshrc`)
- run `accretion install` to install dependencies etc.
- run `accretion config apply` to generate the configs using the colors specified in `~/.local/share/accretion-shell/accretion-cli/theme.json` (you can modify this file to change the colors used in the system)

**disclaimer:** accretion-cli does not know your monitor layout our your preference, so it creates a generic hyprlandLocal.lua file. it is strongly recommended to check it and atleast modify the monitor configuration to your liking. this file is persistent after updateing using `accretion update` and while not be overwritten once created.

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
