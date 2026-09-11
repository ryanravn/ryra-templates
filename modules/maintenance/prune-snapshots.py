"""Expire only Ryra's read-only deployment snapshots; preserve recovery points."""
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import subprocess


def prune(root=Path("/.snapshots"), now=None):
    if not root.exists():
        return
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=30)
    for prefix in ("home", "var-lib"):
        candidates = []
        for path in root.iterdir():
            match = re.fullmatch(rf"{prefix}-(\d{{6}}T\d{{6}})", path.name)
            if not match or path.is_symlink() or not path.is_dir():
                continue
            try:
                stamp = datetime.strptime(match[1], "%y%m%dT%H%M%S").replace(
                    tzinfo=timezone.utc
                )
            except ValueError:
                continue
            candidates.append((stamp, path))
        candidates.sort(key=lambda item: item[0], reverse=True)
        for stamp, path in candidates[3:]:
            if stamp >= cutoff:
                continue
            # Fail closed on writable subvolumes, ordinary directories or errors.
            result = subprocess.run(
                ["btrfs", "property", "get", "-ts", str(path), "ro"],
                check=True, capture_output=True, text=True,
            )
            if result.stdout.strip() != "ro=true":
                continue
            subprocess.run(["btrfs", "subvolume", "delete", str(path)], check=True)


if __name__ == "__main__":
    prune()
