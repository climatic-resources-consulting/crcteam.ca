#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/var/www/crc"
OWNER="www-data"
GROUP="www-data"
CLEAN_TARGET="true"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Deploy this website to /var/www/crc by default.

Options:
  --target <path>    Target deployment directory (default: /var/www/crc)
  --owner <user>     Owner for deployed files (default: www-data)
  --group <group>    Group for deployed files (default: www-data)
  --no-clean         Do not delete existing files from the target before copy
  --help             Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    --owner)
      OWNER="${2:-}"
      shift 2
      ;;
    --group)
      GROUP="${2:-}"
      shift 2
      ;;
    --no-clean)
      CLEAN_TARGET="false"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET_DIR" ]]; then
  echo "Error: target directory cannot be empty." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROBOTS="$SCRIPT_DIR/robots.txt"

if [[ "$EUID" -eq 0 ]]; then
  SUDO=""
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Error: sudo is required when not running as root." >&2
    exit 1
  fi
  SUDO="sudo"
fi

echo "Deploying website from: $SCRIPT_DIR"
echo "Target directory: $TARGET_DIR"

if [[ ! -f "$SOURCE_ROBOTS" ]]; then
  echo "Error: robots.txt was not found at $SOURCE_ROBOTS" >&2
  echo "Create robots.txt in the repository root before deploying." >&2
  exit 1
fi

$SUDO mkdir -p "$TARGET_DIR"

if [[ "$CLEAN_TARGET" == "true" ]]; then
  echo "Cleaning target directory..."
  $SUDO find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

echo "Copying website files..."
$SUDO tar \
  --exclude='.git' \
  --exclude='install.sh' \
  -C "$SCRIPT_DIR" \
  -cf - . | $SUDO tar -C "$TARGET_DIR" -xf -

if [[ ! -f "$TARGET_DIR/robots.txt" ]]; then
  echo "Error: robots.txt was not deployed to $TARGET_DIR" >&2
  exit 1
fi

echo "Setting ownership to $OWNER:$GROUP..."
$SUDO chown -R "$OWNER:$GROUP" "$TARGET_DIR"

echo "Setting file permissions..."
$SUDO find "$TARGET_DIR" -type d -exec chmod 755 {} +
$SUDO find "$TARGET_DIR" -type f -exec chmod 644 {} +

echo "Deployment complete."
echo "Website files are now in: $TARGET_DIR"