"""Mission manager V1 stub with scenario parse demo."""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover - bootstrap environment guard
    print("missing dependency: pyyaml (pip install pyyaml)", file=sys.stderr)
    raise SystemExit(2) from exc


def load_steps(profile_path: Path) -> list[str]:
    with profile_path.open("r", encoding="utf-8") as handle:
        profile = yaml.safe_load(handle)

    return profile["spec"]["mission_scenario"]["steps"]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    profile_path = root / "profiles" / "full_sitl.yaml"

    try:
        steps = load_steps(profile_path)
    except Exception as err:  # pragma: no cover - bootstrap CLI path
        print(f"failed to load mission scenario: {err}", file=sys.stderr)
        return 1

    print("mission scenario from full_sitl.yaml:")
    for step in steps:
        if step == "waypoint":
            print("- fly to waypoint")
        else:
            print(f"- {step}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
