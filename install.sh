#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Staff+ Skills — installer & updater
# Wires or updates the pack into a repository for Claude Code, Cursor, Windsurf,
# and Antigravity.
# Safe to re-run: overwrites generated adapter rules and syncs skills.
#
#   Usage:  ./install.sh            # install / update for all detected tools
#           ./install.sh --update   # explicitly sync and prune old skills
#           ./install.sh --verify   # validate skill schema & router registration
#           ./install.sh --package  # bundle release zip for distribution
#           ./install.sh --git-hook # install pre-commit validation hook
#           ./install.sh --list     # show what would be wired/updated
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

if [ "${1:-}" = "--verify" ]; then
  exec python3 "$PACK_DIR/scripts/validate_skills.py"
fi

if [ "${1:-}" = "--package" ]; then
  exec bash "$PACK_DIR/scripts/package.sh"
fi

if [ "${1:-}" = "--git-hook" ]; then
  HOOK_PATH="$ROOT/.git/hooks/pre-commit"
  if [ ! -d "$ROOT/.git" ]; then
    echo "Error: $ROOT is not a git repository root."
    exit 1
  fi
  mkdir -p "$ROOT/.git/hooks"
  cat << EOF > "$HOOK_PATH"
#!/usr/bin/env bash
echo "🔍 Running Staff+ Skills pre-commit validation..."
python3 "${REL}/scripts/validate_skills.py"
EOF
  chmod +x "$HOOK_PATH"
  echo "✓ Installed pre-commit hook at $HOOK_PATH"
  exit 0
fi

IS_UPDATE=false
if [ "${1:-}" = "--update" ]; then
  IS_UPDATE=true
fi

echo "Staff+ Skills installer & updater"
echo "  pack   : $PACK_DIR"
echo "  repo   : $ROOT  (pack is at: $REL)"
echo "  skills : ${SKILLS[*]}"
echo

if [ "${1:-}" = "--list" ]; then
  echo "Would wire / update:"
  echo "  - $ROOT/AGENTS.md                     (universal router)"
  echo "  - $ROOT/.cursor/rules/staff-plus.mdc  (Cursor)"
  echo "  - $ROOT/.windsurfrules                (Windsurf)"
  echo "  - $ROOT/.claude/skills/<id>/          (Claude Code, native skills)"
  echo "  - $ROOT/AGENTS.md                     (Antigravity reads it natively)"
  exit 0
fi

# 1) Universal router at the repo root (AGENTS.md).
if [ "$REL" = "." ]; then
  echo "✓ AGENTS.md already at repo root (this pack)."
elif [ -f "$ROOT/AGENTS.md" ]; then
  if grep -q "Staff+ Skills router" "$ROOT/AGENTS.md" 2>/dev/null; then
    rewrite < "$PACK_DIR/AGENTS.md" > "$ROOT/AGENTS.md"
    echo "✓ updated $ROOT/AGENTS.md (universal router)"
  else
    echo "! $ROOT/AGENTS.md exists — not overwriting custom router. Verify it imports ${REL}/AGENTS.md"
  fi
else
  rewrite < "$PACK_DIR/AGENTS.md" > "$ROOT/AGENTS.md"
  echo "✓ wrote $ROOT/AGENTS.md (universal router)"
fi

# 2) Cursor — always-on router rule.
mkdir -p "$ROOT/.cursor/rules"
{
  printf -- '---\n'
  printf 'description: Staff+ Skills router — auto-detects the stack and loads the matching skill.\n'
  printf 'alwaysApply: true\n'
  printf -- '---\n\n'
  rewrite < "$PACK_DIR/AGENTS.md"
} > "$ROOT/.cursor/rules/staff-plus.mdc"
echo "✓ updated $ROOT/.cursor/rules/staff-plus.mdc"

# 3) Windsurf — .windsurfrules at repo root.
rewrite < "$PACK_DIR/AGENTS.md" > "$ROOT/.windsurfrules"
echo "✓ updated $ROOT/.windsurfrules"

# 4) Claude Code — native skills sync & prune orphans.
mkdir -p "$ROOT/.claude/skills"

# Copy/update valid skills
for id in "${SKILLS[@]}"; do
  mkdir -p "$ROOT/.claude/skills/$id"
  cp -f "$PACK_DIR/skills/$id/"* "$ROOT/.claude/skills/$id/"
done

# Prune orphaned skill directories in .claude/skills/ that no longer exist in the pack
if [ -d "$ROOT/.claude/skills" ]; then
  for existing_dir in "$ROOT/.claude/skills"/*/; do
    [ -d "$existing_dir" ] || continue
    existing_id="$(basename "$existing_dir")"
    
    # Check if existing_id is in SKILLS array
    is_valid=false
    for valid_id in "${SKILLS[@]}"; do
      if [ "$existing_id" = "$valid_id" ]; then
        is_valid=true
        break
      fi
    done

    if [ "$is_valid" = false ]; then
      rm -rf "$existing_dir"
      echo "  ↳ pruned orphaned skill from .claude/skills/$existing_id"
    fi
  done
fi

if [ ! -f "$ROOT/CLAUDE.md" ]; then
  { echo "# Project instructions"; echo; echo "@AGENTS.md"; } > "$ROOT/CLAUDE.md"
  echo "✓ wrote $ROOT/CLAUDE.md (imports AGENTS.md)"
else
  echo "! $ROOT/CLAUDE.md exists — ensure '@AGENTS.md' is imported."
fi
echo "✓ synced ${#SKILLS[@]} skills into $ROOT/.claude/skills/"

# 5) Antigravity (Google)
echo "  ↳ Antigravity reads $ROOT/AGENTS.md natively — updated in step 1."

echo
if [ "$IS_UPDATE" = true ]; then
  echo "Update complete. Reload your editor/agent to apply the changes."
else
  echo "Done. Reload your editor/agent so it picks up the new rules."
fi

