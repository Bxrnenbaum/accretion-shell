#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Bxrnenbaum/accretion-shell.git"
REPO_DIR="$HOME/.local/share/accretion-shell"
BIN_DIR="$HOME/.local/bin"
BINARY="$BIN_DIR/accretion"

mkdir -p "$BIN_DIR" "$(dirname "$REPO_DIR")"

if [[ -e "$REPO_DIR" ]]; then
  echo "Repository already exists: $REPO_DIR"
  echo "Update it manually, then run: accretion install"
  exit 1
fi

echo "Cloning Accretion Shell..."
git clone "$REPO_URL" "$REPO_DIR"

ARCH="$(uname -m)"

case "$ARCH" in
x86_64) RID="linux-x64" ;;
aarch64 | arm64) RID="linux-arm64" ;;
*)
  echo "Unsupported architecture: $ARCH" >&2
  exit 1
  ;;
esac

# Prefer a prebuilt release, so users dont need the .NET SDK.
RELEASE_URL="https://github.com/Bxrnenbaum/accretion-shell/releases/latest/download/accretion-cli-$RID"

if curl -fL "$RELEASE_URL" -o "$BINARY"; then
  chmod +x "$BINARY"
else
  rm -f "$BINARY"

  if ! command -v dotnet >/dev/null 2>&1; then
    echo "No prebuilt CLI release found and dotnet is not installed." >&2
    echo "Publish a release binary or install the .NET SDK to build from source." >&2
    exit 1
  fi

  echo "No release binary found; building with the installed .NET SDK..."

  dotnet publish "$REPO_DIR/accretion-cli/accretion-cli.csproj" \
    -c Release \
    -r "$RID" \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:IncludeNativeLibrariesForSelfExtract=true \
    -o "$BIN_DIR/accretion-publish"

  install -m 755 "$BIN_DIR/accretion-publish/accretion-cli" "$BINARY"
  rm -rf "$BIN_DIR/accretion-publish"
fi

echo "Installing configuration..."
"$BINARY" install

echo
echo "Accretion Shell installation complete."
echo "If needed, add ~/.local/bin to your PATH."
