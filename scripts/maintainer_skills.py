#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

CATALOG = Path("docs/agents/maintainer-skills")
LOCK = Path("maintainer-skills-lock.json")
ATTENDEE = Path(".github/skills")
PROJECTIONS = (Path(".agents/skills"), Path(".claude/skills"))
MARKER = ".maintainer-skills-managed.json"


class SkillError(RuntimeError):
    pass


def content_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(path for path in root.rglob("*") if path.is_file()):
        relative = path.relative_to(root).as_posix().encode()
        content = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def directory_names(root: Path) -> set[str]:
    if not root.is_dir():
        raise SkillError(f"missing directory: {root.as_posix()}")
    return {path.name for path in root.iterdir() if path.is_dir()}


def load_json(path: Path, description: str) -> dict:
    if not path.is_file():
        raise SkillError(f"missing {description}: {path.name}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SkillError(f"invalid {description}: {error}") from error
    if not isinstance(data, dict):
        raise SkillError(f"invalid {description}: expected object")
    return data


def attendee_names(root: Path) -> list[str]:
    lock = load_json(root / "skills-lock.json", "attendee lock file")
    locked = set(lock.get("skills", {}))
    installed = directory_names(root / ATTENDEE)
    missing = sorted(installed - locked)
    extra = sorted(locked - installed)
    if missing:
        raise SkillError(
            f"attendee inventory mismatch: missing {', '.join(missing)}"
        )
    if extra:
        raise SkillError(
            f"attendee inventory mismatch: extra {', '.join(extra)}"
        )
    return sorted(locked)


def maintainer_names(root: Path) -> list[str]:
    lock = load_json(root / LOCK, "maintainer lock file")
    if lock.get("version") != 1 or not isinstance(lock.get("skills"), dict):
        raise SkillError("invalid maintainer lock schema")
    catalog_root = root / CATALOG
    locked = set(lock["skills"])
    installed = directory_names(catalog_root)
    missing = sorted(locked - installed)
    extra = sorted(installed - locked)
    if missing:
        raise SkillError(f"catalog inventory mismatch: missing {', '.join(missing)}")
    if extra:
        raise SkillError(f"catalog inventory mismatch: extra {', '.join(extra)}")
    for name in sorted(locked):
        skill_root = catalog_root / name
        if not (skill_root / "SKILL.md").is_file():
            raise SkillError(f"missing SKILL.md: {name}")
        expected = lock["skills"][name].get("contentHash")
        actual = content_hash(skill_root)
        if actual != expected:
            raise SkillError(f"content hash mismatch: {name}")
    return sorted(locked)


def validate(root: Path) -> tuple[list[str], list[str]]:
    attendees = attendee_names(root)
    maintainers = maintainer_names(root)
    duplicates = sorted(set(attendees) & set(maintainers))
    if duplicates:
        raise SkillError(f"duplicate skill across catalogs: {', '.join(duplicates)}")
    return attendees, maintainers


def load_managed_names(projection: Path) -> set[str]:
    marker = projection / MARKER
    if not marker.exists():
        return set()
    data = load_json(marker, "projection marker")
    names = data.get("skills")
    if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
        raise SkillError(f"invalid projection marker: {marker.as_posix()}")
    return set(names)


def source_skills(
    root: Path, attendees: list[str], maintainers: list[str]
) -> dict[str, Path]:
    sources = {name: root / ATTENDEE / name for name in attendees}
    sources.update({name: root / CATALOG / name for name in maintainers})
    return sources


def preflight_projection(
    root: Path, projection: Path, expected: set[str]
) -> set[str]:
    absolute = root / projection
    managed = load_managed_names(absolute)
    for name in expected:
        destination = absolute / name
        if destination.exists() and name not in managed:
            raise SkillError(
                f"refusing to overwrite unmanaged skill: "
                f"{(projection / name).as_posix()}"
            )
    return managed


def remove_path(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def project(root: Path) -> None:
    attendees, maintainers = validate(root)
    sources = source_skills(root, attendees, maintainers)
    expected = set(sources)
    managed_by_projection = {
        projection: preflight_projection(root, projection, expected)
        for projection in PROJECTIONS
    }
    for projection in PROJECTIONS:
        absolute = root / projection
        absolute.mkdir(parents=True, exist_ok=True)
        managed = managed_by_projection[projection]
        for name in sorted(managed | expected):
            destination = absolute / name
            if destination.exists():
                if name not in managed:
                    continue
                remove_path(destination)
            if name in sources:
                shutil.copytree(sources[name], destination)
        marker = absolute / MARKER
        marker.write_text(
            json.dumps({"version": 1, "skills": sorted(expected)}, indent=2)
            + "\n",
            encoding="utf-8",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("validate", "project"))
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command == "validate":
            validate(root)
            print("maintainer skills are structurally valid")
        else:
            project(root)
            print("maintainer skills projected for local clients")
    except SkillError as error:
        print(f"maintainer skills invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
