# Accretion-shell
> A shell containing a [Quickshell](https://quickshell.outfoxxed.me/) config replacing [Malachite-Quickshell](https://github.com/Bxrnenbaum/Malachite-Quickshell/), a config for kitty, hyprland, hypridle and hyprlock aswell as a c# tool for managing themes, dependencies etc.
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
>theme switching in action

*All wallpapers have been made using blender*

## Compatibility
- **Arch** and derivatives: compatible (tested on Arch and EndeavourOS)
- **Fedora**: mostly compatible (Hyprland is not officially supported, so enabling it through COPR is required)
- **NixOS**: planned but untested
- **OpenSUSE**: should be compatible (I could not get hyprland working. if you know how to correctly set up nvidia drivers on OpenSUSE lmk)

> all testing environments currently run on x64 but except for OS availability, nothing should stop compatibility for ARM systems.  

## Installation
**.NET10.0 is required at the moment to build the project. binaries may come when I am motivated enough to play around with Github-actions**

1. Run the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/Bxrnenbaum/accretion-shell/main/scripts/bootstrap.sh | bash
```

2. Install dependencies and link up configs:

```bash
accretion install
```

3. Generate the configs using the colors specified in `~/.local/share/accretion-shell/accretion-cli/theme.json` (you can modify this file to change the colors used in the system):

```bash
accretion config apply
```

**If the accretion command isnt available to you, try adding `.local/bin` to path:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```
> swap out `.bashrc` with `.zshrc` for example, if you dont use bash.


### Operating system specific problems and solutions
#### Fedora:
- Hyprland isnt supported officially, so you have to enable it through COPR first:
  ```bash
  sudo dnf copr enable lionheartp/hyprland
  ```
  > note: `lionheartp/hyprland` worked best for me, you might want to try other repos if you experience problems with this one.

- from personal testing ive experienced cursor flickering, setting `no_hardware_cursor = true` in `.config/hypr/hyprlandLocal.lua` fixed it for me

#### OpenSUSE:
- quickshell isnt available in the official repos. its easiest to add this repo before running `accretion install`:
  ```bash
  sudo zypper addrepo https://download.opensuse.org/repositories/home:AvengeMedia:danklinux/openSUSE_Tumbleweed/home:AvengeMedia:danklinux.repo
  ```

## Post install (Do not skip this)
this repo comes with a generic hyprland base setup which serves to get you started, not to be a permanent solution. It is more than recommended to:
- setup your monitors correctly
- change your keyboard layout (default: us)
in `.config/hypr/hyprlandLocal.lua`. this file will not be overwritten by updates and is used for device specific settings.

the weather widget fetches data for vienna by default, so assuming you arent from vienna, you should consider changing your location like this:
```bash
accretion config location <lat> <lon>
```
> Note: we use a very modern and sophisticated coordinate system, so we dont have to deal with a geocoding API.


## Usage

#### accretion-cli

accretion-cli is a c# tool made to manage (almost) everything accretion shell provides.

##### Accretion-cli usage
- **reload configs**
  ```bash
  accretion config apply
  ```
  > regenerates all linked up configs.

- **change theme**
  ```bash
  accretion config theme <theme_name>
  ```
  > switch to a theme defined in `.local/share/accretion/accretion-cli/theme.json`.
  > currently there are 4 predefined themes available, you can show them like this:
  ```bash
  accretion config theme
  ```

- **change location**
  ```bash
  accretion config location <lat> <lon>
  ```
  > changes the location used for the weather widget, might take a few minutes to apply.
  
- **setup symlinks and dependencies**
  ```bash
  accretion install
  ```
  > installs all needed dependencies and links up configs. it will backup existing configs beforehand.

- **update**
  ```bash
  accretion update
  ```
  > pulls the repo and rebuilds the binary if necessary. it is recommended to sometimes check what changed in persistent files like hyprlandLocal.lua, as new features, fixes or similar wont affect untracked files.

- **restore configs**
  ```bash
  accretion uninstall
  ```
  > removes all symlinks and restores backed up configs. the repo located in `.local/share/accretion-shell/` aswell as the accretion binary in `.local/bin/accretion` are not touched and have to be removed manually.


#### currently the following keybinds are configured:
- **SUPER + SHIFT + S**: changed to take a region screenshot using hyprshot
- **SUPER + P**: Cycle between dwindle (default) and scrolling layout
- **SUPER + L**: Lock using hyprlock
- **SUPER + K**: run hyprctl kill
- **SUPER + F**: toggle fullscreen
- **SUPER + R**: open the Quickshell application launcher
- **SUPER + T**: open the Quickshell Bash prompt
- **SUPER + KP_\***: switch to workspaces 11-20
- **SUPER + SHIFT + KP_\***: move a window to workspaces 11-20

aswell as the default hyprland binds, if not overwritten.


## Thanks to
- [Open-Meteo](https://open-meteo.com/) for providing weather data.
- [Github Monaspace](https://github.com/githubnext/monaspace?tab=OFL-1.1-1-ov-file.



## License
This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
