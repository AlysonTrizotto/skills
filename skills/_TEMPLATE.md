---
# --- Routing frontmatter (read by Claude Code, Cursor .mdc, and the AGENTS.md router) ---
name: <skill-id>                    # kebab-case, matches the folder name
description: >-
  Use when <trigger>. Detect via <signal files>. Acts as a Staff+ <role> peer
  focused on <core values>. Keep this <120 chars of the most important part first —
  routers match on the opening words.
domain: <backend|frontend|mobile|devops|qa>
stack: <FastAPI|Laravel|…>
globs: ["**/*.<ext>"]               # Cursor auto-attach hint; optional
tags: ["<TAG_ONE>", "<TAG_TWO>"]    # evidence tags this skill adds on top of the global ones
---

# <Stack> · Staff+ Skill

> One-sentence identity: "Act as a Staff+ <role> peer. <Core value> over <anti-value>."

## When this activates
- Concrete signals that should turn this skill on (files, deps, task phrasing).
- When it should *stay off* (avoid over-triggering).

## Challenge triggers — push back when you see…
Bullet list of concrete situations where a Staff+ peer stops and objects instead of
complying. Each: the smell → the counter-move. This is what makes the skill feel senior.

## Rules (DO) — with rationale
Numbered, imperative, stack-specific. Each rule states the *why* in ≤1 clause. No generic
advice that would apply to any language.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
Table of the 4–8 mistakes most common in this stack.

## Worked examples ❌ → ✅
Two or three short before/after code blocks. Show the *actual* idiom, not pseudocode.

## Review checklist (PR-ready)
- [ ] Checkbox items a reviewer runs down before approving. Concrete and stack-specific.

## Definition of Done
Short paragraph or list: what "done" means for a change in this domain (tests, observability,
docs, rollback, perf budget…).

## Stack-specific gotchas
The traps that bite people who don't know this stack deeply. High signal, low volume.

## Evidence tags
List the skill-specific tags and when to emit each (e.g. `[N+1]`, `[BATTERY_DRAIN]`).
