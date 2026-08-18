#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
python3 "$repo_root/scripts/maintainer_skills.py" project --root "$repo_root"
