"""Retention must never remove recent, unrelated, or writable data."""
import importlib.util
from datetime import datetime, timedelta, timezone
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "pruning", REPO / "modules/maintenance/prune-snapshots.py"
)
pruning = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pruning)


class RetentionTests(unittest.TestCase):
    def test_retention_and_data_boundaries(self):
        now = datetime(2026, 9, 11, tzinfo=timezone.utc)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = set()
            for prefix in ("home", "var-lib"):
                for age in (1, 2, 3, 20, 30, 31, 60):
                    name = f"{prefix}-{now - timedelta(days=age):%y%m%dT%H%M%S}"
                    (root / name).mkdir()
                    if age > 30:
                        expected.add(str(root / name))
            for name in ("personal-backup", "home-000000T000000", "home-200101T000000"):
                (root / name).mkdir()
            (root / "home-190101T000000").symlink_to(root / "personal-backup")
            deleted = set()

            def btrfs(args, **kwargs):
                if args[1] == "property":
                    writable = args[-2].endswith("home-200101T000000")
                    return subprocess.CompletedProcess(args, 0, "ro=false\n" if writable else "ro=true\n")
                deleted.add(args[-1])
                return subprocess.CompletedProcess(args, 0)

            with patch.object(pruning.subprocess, "run", side_effect=btrfs):
                pruning.prune(root, now)
            self.assertEqual(deleted, expected)

    def test_three_old_recovery_points_survive_per_kind(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for prefix in ("home", "var-lib"):
                for day in (1, 2, 3):
                    (root / f"{prefix}-20010{day}T000000").mkdir()
            with patch.object(pruning.subprocess, "run") as run:
                pruning.prune(root)
                run.assert_not_called()

    def test_inspection_failure_stops_deletion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for day in (1, 2, 3, 4):
                (root / f"home-20010{day}T000000").mkdir()
            with patch.object(pruning.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "btrfs")) as run:
                with self.assertRaises(subprocess.CalledProcessError):
                    pruning.prune(root)
                self.assertEqual(run.call_count, 1)
                self.assertEqual(run.call_args.args[0][1], "property")



if __name__ == "__main__":
    unittest.main()
