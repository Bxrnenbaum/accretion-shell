#!/usr/bin/env bash
# accretion-shell installer
# Installs everything under ./.config into $XDG_CONFIG_HOME (default ~/.config).
#
# Local:  ./install.sh [options]
# Remote: curl -fsSL https://raw.githubusercontent.com/Bxrnenbaum/accretion-shell/main/install.sh | bash -s -- [options]
set -euo pipefail

REPO_URL="https://github.com/Bxrnenbaum/accretion-shell.git"
CLONE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/accretion-shell"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$DEST/accretion-backup-$(date +%Y%m%d-%H%M%S)"

LOCAL_FILES=("hypr/hyprlandLocal.lua")

ARCH_PKGS=(hyprland hypridle hyprlock quickshell curl jq networkmanager)

MODE=link # link | copy
DRY=0
DEPS=1
YES=0
UNINSTALL=0
REPO_DIR=""
SRC=""

usage() {
  cat <<USAGE
Usage: ./install.sh [options]

  --copy        Copy files instead of symlinking them to this repo
  --dry-run     Print what would happen, change nothing
                (when run via curl, the repo is still cloned first)
  --no-deps     Skip dependency check/installation
  --yes, -y     Don't ask for confirmation (required without a terminal)
  --uninstall   Remove symlinks created by this script (copies are left alone)
  --help, -h    Show this help

Existing files are moved to a timestamped backup directory, never deleted.
USAGE
}

log() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

run() {
  if ((DRY)); then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

is_local_file() {
  local rel="$1" f
  for f in "${LOCAL_FILES[@]}"; do [[ "$f" == "$rel" ]] && return 0; done
  return 1
}

repo_files() {
  (cd "$SRC" && find . -type f -print0 | sort -z) | while IFS= read -r -d '' f; do
    printf '%s\0' "${f#./}"
  done
}

install_deps_arch() {
  local missing=() p ans
  for p in "${ARCH_PKGS[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing+=("$p")
  done
  if ((${#missing[@]} == 0)); then
    log "All dependencies already installed."
    return
  fi

  log "Missing packages: ${missing[*]}"
  if ((!YES && !DRY)); then
    read -r -p "Install them now? [Y/n] " ans
    if [[ ! "${ans:-Y}" =~ ^[Yy]$ ]]; then
      warn "Skipping dependency install."
      return
    fi
  fi

  if command -v paru &>/dev/null; then
    run paru -S --needed "${missing[@]}"
  elif command -v yay &>/dev/null; then
    run yay -S --needed "${missing[@]}"
  else
    run sudo pacman -S --needed "${missing[@]}"
  fi
}

check_deps() {
  local id="unknown" like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-unknown}"
    like="${ID_LIKE:-}"
  fi

  if [[ "$id" == "arch" || "$like" == *arch* ]]; then
    install_deps_arch
  else
    warn "Automatic dependency install is only implemented for Arch-based distros."
    warn "Please make sure these are installed: ${ARCH_PKGS[*]}"
  fi

  if ! command -v Hyprland &>/dev/null && ! command -v hyprland &>/dev/null; then
    warn "Hyprland not found in PATH. hyprland.lua requires a version with Lua config support."
  fi
}

bootstrap() {
  local script_path="${BASH_SOURCE[0]:-}"
  if [[ -n "$script_path" && -f "$script_path" ]]; then
    REPO_DIR="$(cd "$(dirname "$script_path")" && pwd)"
  fi
  if [[ -n "$REPO_DIR" && -d "$REPO_DIR/.config" ]]; then
    return
  fi

  command -v git >/dev/null || die "git is required."
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only
  else
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
  fi

  if [[ -r /dev/tty ]]; then
    exec bash "$CLONE_DIR/install.sh" "$@" </dev/tty
  else
    exec bash "$CLONE_DIR/install.sh" "$@"
  fi
}

do_uninstall() {
  local rel target
  log "Removing symlinks that point into $SRC"
  while IFS= read -r -d '' rel; do
    target="$DEST/$rel"
    is_local_file "$rel" && continue
    if [[ -L "$target" && "$(readlink -- "$target")" == "$SRC/$rel" ]]; then
      run rm -- "$target"
    fi
  done < <(repo_files)
  log "Done. Local files (e.g. hyprlandLocal.lua) and any backups were left untouched."
}

do_install() {
  local rel src target backed_up=0 ans scripts_dir

  log "Source:      $SRC"
  log "Destination: $DEST"
  log "Mode:        $MODE"
  if ((!YES && !DRY)); then
    read -r -p "Proceed? [Y/n] " ans
    [[ "${ans:-Y}" =~ ^[Yy]$ ]] || die "Aborted."
  fi

  while IFS= read -r -d '' rel; do
    src="$SRC/$rel"
    target="$DEST/$rel"

    if is_local_file "$rel"; then
      if [[ -e "$target" ]]; then
        log "Keeping existing local file: $rel"
        continue
      fi
      run mkdir -p -- "$(dirname "$target")"
      run cp -- "$src" "$target"
      log "Created local file: $rel"
      continue
    fi

    if [[ -L "$target" && "$(readlink -- "$target")" == "$src" ]]; then
      continue
    fi

    if [[ "$MODE" == copy && -f "$target" && ! -L "$target" ]] && cmp -s "$src" "$target"; then
      continue
    fi

    if [[ -e "$target" || -L "$target" ]]; then
      run mkdir -p -- "$BACKUP/$(dirname "$rel")"
      run mv -- "$target" "$BACKUP/$rel"
      backed_up=1
    fi

    run mkdir -p -- "$(dirname "$target")"
    if [[ "$MODE" == link ]]; then
      run ln -s -- "$src" "$target"
    else
      run cp -- "$src" "$target"
    fi
  done < <(repo_files)

  if [[ "$MODE" == link ]]; then
    scripts_dir="$SRC/hypr/scripts"
  else
    scripts_dir="$DEST/hypr/scripts"
  fi
  if [[ -d "$scripts_dir" ]]; then
    run find "$scripts_dir" -type f -name '*.sh' -exec chmod +x {} +
  fi

  if ((backed_up)); then
    log "Previous files were moved to: $BACKUP"
  fi
  log "Done. Log out and back into Hyprland (or reload it) to apply."
  if [[ "$MODE" == link ]]; then
    log "Symlink mode: keep $SRC in place, your config points into it."
  fi
}

main() {
  local orig_args=("$@")

  while (($#)); do
    case "$1" in
    --copy) MODE=copy ;;
    --dry-run) DRY=1 ;;
    --no-deps) DEPS=0 ;;
    --yes | -y) YES=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --help | -h)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown option: $1"
      ;;
    esac
    shift
  done

  ((EUID != 0)) || die "Do not run as root; sudo is used only when installing packages."

  bootstrap "${orig_args[@]}"
  SRC="$REPO_DIR/.config"

  if ((UNINSTALL)); then
    do_uninstall
    exit 0
  fi

  if ((DEPS)); then
    check_deps
  fi
  do_install
}

main "$@"
