"""Run the actual library with mocked Roblox services using the official Luau CLI."""

import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", default="luau", help="Path to the Luau CLI")
    parser.add_argument("--source-ref", help="Test library sources from a Git ref")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    def read_source(path):
        if args.source_ref:
            return subprocess.check_output(
                ["git", "show", f"{args.source_ref}:{path}"], cwd=root, text=True,
                encoding="utf-8",
            )
        return (root / path).read_text(encoding="utf-8")

    combo = read_source("src/ComboQueries.luau")
    combo = combo.replace("require(script.Parent.Types)", "true")
    source = read_source("src/init.luau")
    source = source.replace("require(script.ComboQueries)", f"(function()\n{combo}\nend)()")
    source = source.replace("require(script.Types)", "true")
    suite = (root / "tests/device_keybinds.luau").read_text(encoding="utf-8")
    bundle = suite.replace("-- LIBRARY_SOURCE", source)
    with tempfile.TemporaryDirectory(prefix="omrezkeybind-tests-") as tmp:
        path = Path(tmp) / "suite.luau"
        path.write_text(bundle, encoding="utf-8")
        return subprocess.run([args.luau, str(path)], check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
