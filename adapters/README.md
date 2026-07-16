# Adapters — manual integration

`install.sh` wires everything below automatically. This page is for when you want to do it
by hand or understand what each platform reads. In all cases the **single source of truth**
is [`../AGENTS.md`](../AGENTS.md) (the router) plus the skill files under [`../skills/`](../skills/).

Assume `PACK` = the folder where this pack lives inside your repo (e.g. `staff-plus-skills/`,
or `.` if you dropped the pack at the repo root). Rewrite `skills/...` paths accordingly.

---

## Universal (any AGENTS.md-aware agent)

Place an `AGENTS.md` at your **repo root**. If the pack is already at the root, you're done —
`AGENTS.md` is the router. If the pack is in a subfolder, either copy `PACK/AGENTS.md` to the
root (fixing the `skills/...` links to `PACK/skills/...`) or add one line at the top of your
existing root `AGENTS.md`:

```md
> Follow the Staff+ Skills router at PACK/AGENTS.md (treat its skill paths as relative to PACK/).
```

Read by: Claude Code, Cursor, and a growing set of agents that honor `AGENTS.md`.

---

## Claude Code (native skills — best experience)

Claude Code auto-invokes skills from `.claude/skills/<id>/SKILL.md` based on each skill's
`description` frontmatter. Copy every skill dir in:

```bash
mkdir -p .claude/skills
cp -r PACK/skills/*/ .claude/skills/     # dir name must equal the skill's `name:`
```

Also import the global contract into project memory so it applies on top of every skill:

```md
# CLAUDE.md
@AGENTS.md
```

No `skills/_TEMPLATE.md` copy needed — it isn't a skill (it has no runnable `name` target).

---

## Cursor

Cursor reads `.cursor/rules/*.mdc`. Create one always-on router rule:

```md
---
description: Staff+ Skills router — auto-detects the stack and loads the matching skill.
alwaysApply: true
---

<paste the contents of PACK/AGENTS.md here, with skills/... rewritten to PACK/skills/...>
```

Optional: for per-file-type auto-attach, add one `.mdc` per skill using its `globs`
frontmatter (e.g. `globs: ["**/*.py"]` for `backend-fastapi`) and reference the skill with
`@PACK/skills/<id>/SKILL.md` in the body.

---

## Windsurf

Windsurf reads `.windsurfrules` at the repo root. Put the router there:

```bash
cp PACK/AGENTS.md .windsurfrules     # rewrite skills/... to PACK/skills/... if in a subfolder
```

If `.windsurfrules` already exists, prepend the same one-line pointer shown in the Universal
section. Mind Windsurf's character limit — the router is compact by design, but trim the
skill catalog table if you hit it.

---

## GitHub Copilot / others

Any agent that reads repository instruction files can use the router. Point its instruction
file (e.g. `.github/copilot-instructions.md`) at `PACK/AGENTS.md` with the same one-line
pointer. The detection protocol and skill files are platform-agnostic Markdown.
