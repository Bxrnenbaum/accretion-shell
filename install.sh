#!/usr/bin/env bash
# accretion-shell installer
# Installs everything under ./.config into $XDG_CONFIG_HOME (default ~/.config).
set -euo pipefail

REPO_URL="https://github.com/Bxrnenbaum/accretion-shell.git"
CLONE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/accretion-shell"

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
REPO_DIR=""
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
fi

if [[ -z "$REPO_DIR" || ! -d "$REPO_DIR/.config" ]]; then
  command -v git >/dev/null || {
    echo "git is required" >&2
    exit 1
  }
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only
  else
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
  fi
  exec bash "$CLONE_DIR/install.sh" "$@" </dev/tty
fi

SRC="$REPO_DIR/.config"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$DEST/accretion-backup-$(date +%Y%m%d-%H%M%S)"

LOCAL_FILES=("hypr/hyprlandLocal.lua")

ARCH_PKGS=(hyprland hypridle hyprlock quickshell curl jq networkmanager)

MODE=link # link | copy
DRY=0
DEPS=1
YES=0
UNINSTALL=0

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  --copy        Copy files instead of symlinking them to this repo
  --dry-run     Print what would happen, change nothing
  --no-deps     Skip dependency check/installation
  --yes, -y     Don't ask for confirmation
  --uninstall   Remove symlinks created by this script (copies are left alone)
  --help, -h    Show this help

Existing files are moved to a timestamped backup directory, never deleted.
EOF
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
[[ -d "$SRC" ]] || die "Cannot find $SRC (run this script from the repo)."

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

# uninstall
if ((UNINSTALL)); then
  log "Removing symlinks that point into $SRC"
  while IFS= read -r -d '' rel; do
    target="$DEST/$rel"
    if is_local_file "$rel"; then continue; fi
    if [[ -L "$target" && "$(readlink -- "$target")" == "$SRC/$rel" ]]; then
      run rm -- "$target"
    fi
  done < <(repo_files)
  log "Done. Local files (e.g. hyprlandLocal.lua) and any backups were left untouched."
  exit 0
fi

# dependencies
install_deps_arch() {
  local missing=() p
  for p in "${ARCH_PKGS[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing+=("$p")
  done
  ((${#missing[@]})) || {
    log "All dependencies already installed."
    return
  }

  log "Missing packages: ${missing[*]}"
  if ((!YES && !DRY)); then
    read -r -p "Install them now? [Y/n] " ans
    [[ "${ans:-Y}" =~ ^[Yy]$ ]] || {
      warn "Skipping dependency install."
      return
    }
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

  command -v Hyprland &>/dev/null || command -v hyprland &>/dev/null ||
    warn "Hyprland not found in PATH. hyprland.lua requires a version with Lua config support."
}

((DEPS)) && check_deps

# install
log "Source:      $SRC"
log "Destination: $DEST"
log "Mode:        $MODE"
if ((!YES && !DRY)); then
  read -r -p "Proceed? [Y/n] " ans
  [[ "${ans:-Y}" =~ ^[Yy]$ ]] || die "Aborted."
fi

backed_up=0
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

if [[ -d "$SRC/hypr/scripts" ]]; then
  if [[ "$MODE" == link ]]; then
    run chmod +x "$SRC"/hypr/scripts/*.sh
  else
    run chmod +x "$DEST"/hypr/scripts/*.sh
  fi
fi

((backed_up)) && log "Previous files were moved to: $BACKUP"
log "Done. Log out and back into Hyprland (or reload it) to apply."
[[ "$MODE" == link ]] && log "Symlink mode: keep this repo in place, the config points into it."
exit 0
