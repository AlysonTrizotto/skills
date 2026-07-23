#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Staff+ Skills — packaging script for commercial distribution
# Bundles clean skills pack into a release zip (dist/staff-plus-skills.zip).
#
#   Usage:  ./scripts/package.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PACK_DIR/dist"
ZIP_NAME="staff-plus-skills.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "📦 Staff+ Skills Bundler"
echo "  Source : $PACK_DIR"
echo "  Target : $ZIP_PATH"
echo

# 1) Validate skills before packaging
echo "🔍 Validating skills integrity..."
python3 "$PACK_DIR/scripts/validate_skills.py"
echo

# 2) Create clean build directory
mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"

# 3) Build zip excluding git & local IDE artifacts
echo "⚙️ Building $ZIP_NAME..."
cd "$PACK_DIR"

zip -r "$ZIP_PATH" . \
  -x "*.git*" \
  -x ".claude/*" \
  -x ".cursor/*" \
  -x ".windsurfrules" \
  -x "CLAUDE.md" \
  -x "dist/*" \
  -x "website/*" \
  -x ".gitignore" \
  -x "*.DS_Store" > /dev/null

SIZE=$(du -h "$ZIP_PATH" | cut -f1)

echo "✅ Created commercial distribution package:"
echo "   Archive: $ZIP_PATH"
echo "   Size   : $SIZE"
echo
echo "🚀 Ready for deployment on Kiwify, LemonSqueezy, or Gumroad!"
