#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Staff+ Skills — installer
# Wires the pack into a repository for Claude Code, Cursor, and Windsurf.
# Safe to re-run: generated adapter files are overwritten, your files are not.
#
#   Usage:  ./install.sh            # install for all detected/known tools
#           ./install.sh --list     # just show what would be wired, do nothing
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$PACK_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PACK_DIR")"

# Path from the repo root to this pack ("." when the pack lives at the root).
if [ "$PACK_DIR" = "$ROOT" ]; then REL="."; else REL="${PACK_DIR#"$ROOT"/}"; fi

# Rewrite in-pack "skills/..." references so they resolve from the repo root.
rewrite() {
  if [ "$REL" = "." ]; then cat; else sed "s#\bskills/#${REL}/skills/#g"; fi
}

# Collect skill ids (directories under skills/ that contain a SKILL.md).
SKILLS=()
for d in "$PACK_DIR"/skills/*/; do
  [ -f "${d}SKILL.md" ] && SKILLS+=("$(basename "$d")")
done

echo "Staff+ Skills installer"
echo "  pack : $PACK_DIR"
echo "  repo : $ROOT  (pack is at: $REL)"
echo "  skills: ${SKILLS[*]}"
echo

if [ "${1:-}" = "--list" ]; then
  echo "Would wire:"
  echo "  - $ROOT/AGENTS.md                     (universal router)"
  echo "  - $ROOT/.cursor/rules/staff-plus.mdc  (Cursor)"
  echo "  - $ROOT/.windsurfrules                (Windsurf)"
  echo "  - $ROOT/.claude/skills/<id>/          (Claude Code, native skills)"
  echo "  - $ROOT/AGENTS.md                     (Antigravity reads it natively)"
  exit 0
fi

# 1) Universal router at the repo root (AGENTS.md). Only create if missing so we
#    never clobber an existing one; if it exists we leave it and print a hint.
if [ "$REL" = "." ]; then
  echo "✓ AGENTS.md already at repo root (this pack)."
elif [ -f "$ROOT/AGENTS.md" ]; then
  echo "! $ROOT/AGENTS.md exists — not overwriting. Add this line near the top:"
  echo "    > Follow the Staff+ Skills router at ${REL}/AGENTS.md"
else
  rewrite < "$PACK_DIR/AGENTS.md" > "$ROOT/AGENTS.md"
  echo "✓ wrote $ROOT/AGENTS.md (universal router)"
fi

# 2) Cursor — one always-on rule that IS the router (points at the skill files).
mkdir -p "$ROOT/.cursor/rules"
{
  printf -- '---\n'
  printf 'description: Staff+ Skills router — auto-detects the stack and loads the matching skill.\n'
  printf 'alwaysApply: true\n'
  printf -- '---\n\n'
  rewrite < "$PACK_DIR/AGENTS.md"
} > "$ROOT/.cursor/rules/staff-plus.mdc"
echo "✓ wrote $ROOT/.cursor/rules/staff-plus.mdc"

# 3) Windsurf — .windsurfrules is read from the repo root.
rewrite < "$PACK_DIR/AGENTS.md" > "$ROOT/.windsurfrules"
echo "✓ wrote $ROOT/.windsurfrules"

# 4) Claude Code — native skills. Copy each skill dir into .claude/skills/<id>/
#    (dir name must equal the skill's `name:` for Claude Code to load it).
mkdir -p "$ROOT/.claude/skills"
for id in "${SKILLS[@]}"; do
  mkdir -p "$ROOT/.claude/skills/$id"
  cp -f "$PACK_DIR/skills/$id/"* "$ROOT/.claude/skills/$id/"
done
# Also expose the router as project memory so Claude Code applies the global contract.
if [ ! -f "$ROOT/CLAUDE.md" ]; then
  { echo "# Project instructions"; echo; echo "@AGENTS.md"; } > "$ROOT/CLAUDE.md"
  echo "✓ wrote $ROOT/CLAUDE.md (imports AGENTS.md)"
else
  echo "! $ROOT/CLAUDE.md exists — add '@AGENTS.md' to import the router."
fi
echo "✓ copied ${#SKILLS[@]} skills into $ROOT/.claude/skills/"

# 5) Antigravity (Google) — reads the repo-root AGENTS.md natively (v1.20.3+), so the
#    router already applies.
echo "  ↳ Antigravity reads $ROOT/AGENTS.md natively — already wired in step 1."

echo
echo "Done. Reload your editor/agent so it picks up the new rules."
