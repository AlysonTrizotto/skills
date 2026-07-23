#!/usr/bin/env python3
"""
Staff+ Skills Validator
Parses and validates all skill definitions (SKILL.md) and router configuration (AGENTS.md).
Usage: python3 scripts/validate_skills.py
"""

import sys
import os
import re
from pathlib import Path

REQUIRED_FRONTMATTER_KEYS = ["name", "description", "domain", "stack", "tags"]
REQUIRED_SECTIONS = [
    "When this activates",
    "Challenge triggers",
    "Rules (DO)",
    "Anti-patterns (DON'T)",
    "Worked examples",
    "Review checklist",
    "Definition of Done",
    "Evidence tags",
]

def parse_frontmatter(content: str):
    if not content.startswith("---"):
        return None, "Missing frontmatter opening '---'"
    parts = content.split("---", 2)
    if len(parts) < 3:
        return None, "Malformed frontmatter syntax"
    
    yaml_text = parts[1]
    body = parts[2]
    
    data = {}
    for line in yaml_text.strip().splitlines():
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if val.startswith(">-") or val.startswith(">"):
                val = ""
            data[key] = val
            
    return data, body

def validate_skill(skill_dir: Path) -> list:
    errors = []
    skill_id = skill_dir.name
    skill_file = skill_dir / "SKILL.md"

    if not skill_file.exists():
        return [f"[{skill_id}] Missing SKILL.md file"]

    content = skill_file.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(content)

    if not fm or isinstance(fm, str):
        return [f"[{skill_id}] {body if isinstance(body, str) else 'Invalid frontmatter'}"]

    # Validate frontmatter keys
    for key in REQUIRED_FRONTMATTER_KEYS:
        if key not in fm:
            errors.append(f"[{skill_id}] Missing required frontmatter key: '{key}'")

    # Validate name matches folder
    if fm.get("name") and fm.get("name") != skill_id:
        errors.append(f"[{skill_id}] Frontmatter name '{fm.get('name')}' does not match directory '{skill_id}'")

    # Validate sections in body
    for section in REQUIRED_SECTIONS:
        pattern = re.compile(rf"^##\s+{re.escape(section)}", re.MULTILINE | re.IGNORECASE)
        if not pattern.search(body):
            errors.append(f"[{skill_id}] Missing required section: '## {section}'")

    return errors

def validate_agents_md(root_dir: Path, skill_ids: list) -> list:
    errors = []
    agents_file = root_dir / "AGENTS.md"
    if not agents_file.exists():
        return ["AGENTS.md router file is missing"]

    content = agents_file.read_text(encoding="utf-8")

    for sid in skill_ids:
        if sid not in content:
            errors.append(f"[AGENTS.md] Skill '{sid}' is not registered in AGENTS.md router")

    return errors

def main():
    root_dir = Path(__file__).resolve().parent.parent
    skills_dir = root_dir / "skills"

    if not skills_dir.exists():
        print(f"Error: skills directory not found at {skills_dir}")
        sys.exit(1)

    all_errors = []
    skill_ids = []

    for item in sorted(skills_dir.iterdir()):
        if item.is_dir() and (item / "SKILL.md").exists():
            skill_ids.append(item.name)
            errs = validate_skill(item)
            all_errors.extend(errs)

    agents_errs = validate_agents_md(root_dir, skill_ids)
    all_errors.extend(agents_errs)

    print(f"🔍 Validating {len(skill_ids)} Staff+ Skills in {root_dir.name}...")
    print("-" * 60)

    if all_errors:
        print(f"❌ Found {len(all_errors)} validation error(s):\n")
        for err in all_errors:
            print(f"  • {err}")
        sys.exit(1)
    else:
        print(f"✅ All {len(skill_ids)} skills passed validation successfully!")
        print("  - Frontmatter schema: OK")
        print("  - Required sections: OK")
        print("  - AGENTS.md Router registration: OK")
        sys.exit(0)

if __name__ == "__main__":
    main()
