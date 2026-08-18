#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

CATALOG = Path("docs/agents/maintainer-skills")
LOCK = Path("maintainer-skills-lock.json")
ATTENDEE = Path(".github/skills")
PROJECTIONS = (Path(".agents/skills"), Path(".claude/skills"))
MARKER = ".maintainer-skills-managed.json"
APPROVED_MAINTAINER_SKILLS = frozenset(
    {
        "ask-matt",
        "grill-me",
        "grill-with-docs",
        "handoff",
        "implement",
        "improve-codebase-architecture",
        "research",
        "resolving-merge-conflicts",
        "setup-matt-pocock-skills",
        "teach",
        "to-questionnaire",
        "to-tickets",
        "triage",
        "wait-what",
        "wizard",
        "writing-for-agents",
    }
)
SKILL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
IMPLEMENT_AUTHORITY_CONTRACTS = (
    "Require an authorized Work Contract before implementation.",
    "Pause for the human Commitment Gate before execution.",
    "Commit or push only with explicit human authorization.",
    "Commit your work to the current branch only after explicit human authorization.",
)
PROHIBITED_IMPLEMENT_CONTRACT = "Commit your work to the current branch."


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


def require_skill_name(name: str, description: str) -> None:
    if not SKILL_NAME.fullmatch(name):
        raise SkillError(f"invalid {description} skill name: {name}")


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
    for name in locked | installed:
        require_skill_name(name, "attendee")
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
    for name in locked | installed:
        require_skill_name(name, "maintainer")
    approved_missing = sorted(APPROVED_MAINTAINER_SKILLS - locked)
    approved_extra = sorted(locked - APPROVED_MAINTAINER_SKILLS)
    if approved_missing:
        raise SkillError(
            "approved maintainer inventory mismatch: missing "
            + ", ".join(approved_missing)
        )
    if approved_extra:
        raise SkillError(
            "approved maintainer inventory mismatch: extra "
            + ", ".join(approved_extra)
        )
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
    implement_content = (catalog_root / "implement" / "SKILL.md").read_text(
        encoding="utf-8"
    )
    if not all(
        contract in implement_content for contract in IMPLEMENT_AUTHORITY_CONTRACTS
    ):
        raise SkillError("missing maintainer authority contract: implement")
    if PROHIBITED_IMPLEMENT_CONTRACT in implement_content:
        raise SkillError("conflicting maintainer authority contract: implement")
    return sorted(locked)


def validate_projection_boundary(root: Path) -> None:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or Path(result.stdout.strip()).resolve() != root:
        return
    for projection in (Path(".agents"), Path(".claude")):
        probe = (projection / "skills" / "probe").as_posix()
        ignored = subprocess.run(
            ["git", "-C", str(root), "check-ignore", "--quiet", "--", probe],
            check=False,
        )
        if ignored.returncode != 0:
            raise SkillError(
                f"generated projection is not ignored: {projection.as_posix()}/"
            )
    tracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--", ".agents", ".claude"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    if tracked:
        raise SkillError(f"tracked generated projection: {tracked[0]}")


def validate(root: Path) -> tuple[list[str], list[str]]:
    attendees = attendee_names(root)
    maintainers = maintainer_names(root)
    duplicates = sorted(set(attendees) & set(maintainers))
    if duplicates:
        raise SkillError(f"duplicate skill across catalogs: {', '.join(duplicates)}")
    validate_projection_boundary(root)
    return attendees, maintainers


def load_managed_names(projection: Path) -> set[str]:
    marker = projection / MARKER
    if marker.is_symlink():
        raise SkillError(f"symlinked projection marker: {marker.as_posix()}")
    if not marker.exists():
        return set()
    try:
        before = marker.lstat()
        if not stat.S_ISREG(before.st_mode):
            raise SkillError(f"invalid projection marker: {marker.as_posix()}")
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        descriptor = os.open(marker, flags)
        try:
            opened = os.fstat(descriptor)
            if (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
                raise SkillError(f"symlinked projection marker: {marker.as_posix()}")
            with os.fdopen(descriptor, encoding="utf-8", closefd=False) as marker_file:
                data = json.load(marker_file)
        finally:
            os.close(descriptor)
    except (OSError, json.JSONDecodeError) as error:
        raise SkillError(f"invalid projection marker: {marker.as_posix()}") from error
    if not isinstance(data, dict):
        raise SkillError(f"invalid projection marker: {marker.as_posix()}")
    names = data.get("skills")
    if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
        raise SkillError(f"invalid projection marker: {marker.as_posix()}")
    for name in names:
        require_skill_name(name, "managed")
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
    projection_parent = root / projection.parts[0]
    if projection_parent.is_symlink() or absolute.is_symlink():
        raise SkillError(
            f"symlinked projection root: {projection_parent.relative_to(root).as_posix()}/"
        )
    if (absolute / MARKER).is_symlink():
        raise SkillError(
            f"symlinked projection marker: {(projection / MARKER).as_posix()}"
        )
    try:
        absolute.resolve().relative_to(root.resolve())
    except ValueError as error:
        raise SkillError(
            f"projection root escapes repository: {projection.as_posix()}"
        ) from error
    resolved_projection = absolute.resolve()
    managed = load_managed_names(absolute)
    for name in expected:
        require_skill_name(name, "projected")
        destination = absolute / name
        if destination.parent.resolve() != resolved_projection:
            raise SkillError(f"unsafe projected skill path: {name}")
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


def write_marker(marker: Path, skill_names: set[str]) -> None:
    if marker.is_symlink():
        raise SkillError(f"symlinked projection marker: {marker.as_posix()}")
    payload = json.dumps(
        {"version": 1, "skills": sorted(skill_names)}, indent=2
    ) + "\n"
    descriptor, temporary_name = tempfile.mkstemp(
        dir=marker.parent,
        prefix=f".{MARKER}.",
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as marker_file:
            marker_file.write(payload)
            marker_file.flush()
            os.fsync(marker_file.fileno())
        os.replace(temporary, marker)
    finally:
        if temporary.exists():
            temporary.unlink()


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
        write_marker(marker, expected)


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
