#!/usr/bin/env python3
"""Build a throwaway multi-repo workspace and run jjw st, pull, st on it.

  demo.py        build the workspace and run jjw
  demo.py -i     then open a shell in the workspace, with jjw on PATH

The workspace is kept; its path is printed at the end.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from fixtures import JJW_PATH, advance_origin, commit, git, jj, jj_commit, mkgit_origin, mkjj_clone, use_test_env


def build(ws: Path) -> None:
    origins = ws / ".origins"
    mkgit_origin(ws / "git-on-trunk", origins / "git-on-trunk.git")
    advance_origin(origins / "git-on-trunk.git", origins / "scratch", "upstream work")
    mkgit_origin(ws / "git-uptodate", origins / "git-uptodate.git")
    mkgit_origin(ws / "git-clean-feat", origins / "git-clean-feat.git")
    git(ws / "git-clean-feat", "switch", "-qc", "my-feature")
    commit(ws / "git-clean-feat", "feature work")
    mkgit_origin(ws / "git-dirty-feat", origins / "git-dirty-feat.git")
    git(ws / "git-dirty-feat", "switch", "-qc", "my-feature")
    (ws / "git-dirty-feat" / "uncommitted").write_text("wip")
    (ws / "not-a-repo").mkdir()
    if shutil.which("jj"):
        mkgit_origin(origins / "jj-seed", origins / "jj.git")
        repo = mkjj_clone(origins / "jj.git", ws / "jj-feat")
        jj_commit(repo, "feat 1", "main@origin")
        jj(repo, "bookmark", "create", "my-feature", "-r", "@")
        jj(repo, "new")


def main() -> None:
    ws = Path(tempfile.mkdtemp(prefix="jjw-demo."))
    (ws / ".origins").mkdir()
    use_test_env(ws / ".origins")
    print(f"Building mock workspace at: {ws}")
    build(ws)
    rule = "\x1b[2m" + "─" * 70 + "\x1b[0m"
    for args, title in ((["st"], "jjw st  (before)"), (["pull"], "jjw pull"), (["st"], "jjw st  (after)")):
        print(f"\n{rule}\n\x1b[1m{title}\x1b[0m\n{rule}", flush=True)
        subprocess.run([str(JJW_PATH), *args], cwd=ws)
    print(f"\n{rule}\nWorkspace kept at: \x1b[36m{ws}\x1b[0m\nClean up with:     \x1b[2mrm -rf {ws}\x1b[0m")
    if "-i" in sys.argv[1:]:
        bin_dir = ws / ".origins" / "bin"
        bin_dir.mkdir()
        (bin_dir / "jjw").symlink_to(JJW_PATH)
        env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
        print("\njjw sandbox: try `jjw st`, `jjw pull`, `jjw wip`. Exit the shell to leave.\n")
        subprocess.run([os.environ.get("SHELL", "zsh")], cwd=ws, env=env)


if __name__ == "__main__":
    main()
