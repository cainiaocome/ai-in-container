"""Check project names and existing-session protection across launchers."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
LAUNCHERS = ("pi-here", "claude-here", "codex-here")
MOCK_DOCKER = r'''
docker() {
  case "$1" in
    ps)
      [[ "$*" == "ps -a --format {{.Names}}" ]] || return 42
      [[ "${MOCK_PS_FAILURE:-0}" == 0 ]] || return 43
      printf '%s\n' "${MOCK_EXISTING_NAMES:-}"
      ;;
    run) printf '%s\0' "$@" ;;
    *) printf 'Unexpected Docker command: %s\n' "$*" >&2; return 44 ;;
  esac
}
source "$LAUNCHER_PATH"
'''


class ContainerNameTests(unittest.TestCase):
    def launch(self, launcher, workspace, **settings):
        env = os.environ.copy()
        for name in ("ADDITIONAL_DOCKER_ARGUMENTS", "AGENT_HERE_CONTAINER_NAME",
                     "MOCK_EXISTING_NAMES", "MOCK_PS_FAILURE"):
            env.pop(name, None)
        env.update(settings)
        env["LAUNCHER_PATH"] = str(REPO_ROOT / "bin" / launcher)
        env["AGENT_HERE_HOME_DIR_ON_HOST"] = str(workspace.parent / "state")
        return subprocess.run(["bash", "-c", MOCK_DOCKER, launcher],
                              cwd=workspace, env=env, capture_output=True)

    def test_project_suffix_and_normalization(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            for folder, suffix in (("solana-wallet-cli", "solana-wallet-cli"),
                                   ("other-project", "other-project"),
                                   ("project with spaces", "project-with-spaces")):
                workspace = Path(temp_dir) / folder
                workspace.mkdir()
                for launcher in LAUNCHERS:
                    with self.subTest(folder=folder, launcher=launcher):
                        result = self.launch(launcher, workspace)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        args = result.stdout.decode().split("\0")[:-1]
                        self.assertEqual(args[args.index("--name") + 1],
                                         f"{launcher}-{suffix}")

    def test_existing_session_and_exact_name_override(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir) / "solana-wallet-cli"
            workspace.mkdir()
            for launcher in LAUNCHERS:
                for override in (None, "custom.name"):
                    name = override or f"{launcher}-solana-wallet-cli"
                    settings = {} if override is None else {"AGENT_HERE_CONTAINER_NAME": override}
                    with self.subTest(launcher=launcher, override=override):
                        result = self.launch(launcher, workspace,
                                             MOCK_EXISTING_NAMES=f"unrelated\n{name}\nother", **settings)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertEqual(result.stdout, b"")
                        self.assertIn(name, result.stderr.decode())
                        self.assertIn("already exists", result.stderr.decode())
                        result = self.launch(launcher, workspace,
                                             MOCK_EXISTING_NAMES=f"{name}-other\n{name.replace('.', 'x')}-nearby",
                                             **settings)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        args = result.stdout.decode().split("\0")[:-1]
                        self.assertEqual(args[args.index("--name") + 1], name)

    def test_docker_listing_failure_stops_launch(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            for launcher in LAUNCHERS:
                with self.subTest(launcher=launcher):
                    result = self.launch(launcher, workspace, MOCK_PS_FAILURE="1")
                    self.assertEqual(result.returncode, 43)
                    self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
