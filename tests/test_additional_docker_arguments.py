"""Check Docker argument forwarding without starting agent containers."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
IMAGE = "ghcr.io/cainiaocome/ai-in-container:main"
LAUNCHERS = ("pi-here", "claude-here", "codex-here")
MOCK_DOCKER = r'''
docker() {
  case "$1" in
    ps) return 0 ;;
    run) printf '%s\0' "$@" ;;
    *) return 1 ;;
  esac
}
source "$LAUNCHER_PATH"
'''


class AdditionalDockerArgumentsTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get("RUN_DOCKER_MOUNT_TEST") == "1",
                         "Set RUN_DOCKER_MOUNT_TEST=1 to check mounts with Docker")
    def test_read_only_review_mount(self):
        with tempfile.TemporaryDirectory(prefix="agent-review-") as temp_dir:
            root = Path(temp_dir)
            root.chmod(0o755)
            original = root / "original project"
            original.mkdir()
            original.chmod(0o777)
            (original / "source.txt").write_text("original repository\n")
            workspace = root / "review workspace"
            workspace.mkdir()
            output = workspace / "review-output"
            output.mkdir()
            output.chmod(0o777)
            (workspace / "project").mkdir()
            result = subprocess.run([
                "docker", "run", "--rm", "--user", "1000:1000",
                "--mount", f"type=bind,source={workspace},target=/app/project",
                "--mount", f"type=bind,source={original},target=/app/project/project,readonly",
                "busybox:1.37", "sh", "-ec",
                'test "$(cat /app/project/project/source.txt)" = "original repository"; '
                'if touch /app/project/project/write-attempt; then exit 1; fi; '
                'echo reviewed > /app/project/review-output/result.txt',
            ], check=True, capture_output=True)
            self.assertIn("read-only file system", result.stderr.decode().lower())
            self.assertEqual((output / "result.txt").read_text(), "reviewed\n")
            self.assertFalse((original / "write-attempt").exists())

    def test_literal_arguments_before_image(self):
        cases = (
            (None, []),
            ("", []),
            ("\n\n", []),
            ("--env\nMESSAGE=hello world\n\n--label\nreview=yes",
             ["--env", "MESSAGE=hello world", "--label", "review=yes"]),
            ("--mount\ntype=bind,source=/tmp/original project,target=/app/project,readonly\n",
             ["--mount", "type=bind,source=/tmp/original project,target=/app/project,readonly"]),
            ("--label\nvalue=$HOME $(touch should-not-exist) `id` 'quoted' \"double\" \\ * ;\n  \n",
             ["--label", "value=$HOME $(touch should-not-exist) `id` 'quoted' \"double\" \\ * ;", "  "]),
        )
        with tempfile.TemporaryDirectory(prefix="agent-args-") as temp_dir:
            workspace = Path(temp_dir) / "project with spaces"
            workspace.mkdir()
            for launcher in LAUNCHERS:
                baseline = None
                for value, expected in cases:
                    with self.subTest(launcher=launcher, value=value):
                        env = os.environ.copy()
                        env.pop("ADDITIONAL_DOCKER_ARGUMENTS", None)
                        env.pop("AGENT_HERE_CONTAINER_NAME", None)
                        env["AGENT_HERE_HOME_DIR_ON_HOST"] = str(Path(temp_dir) / "state")
                        env["LAUNCHER_PATH"] = str(REPO_ROOT / "bin" / launcher)
                        if value is not None:
                            env["ADDITIONAL_DOCKER_ARGUMENTS"] = value
                        result = subprocess.run(
                            ["bash", "-c", MOCK_DOCKER, launcher],
                            cwd=workspace, env=env, check=True, capture_output=True,
                        )
                        args = result.stdout.decode().split("\0")[:-1]
                        image_index = args.index(IMAGE)
                        defaults = args[:image_index - len(expected)]
                        if baseline is None:
                            baseline = defaults
                        self.assertEqual(defaults, baseline)
                        self.assertEqual(args[image_index - len(expected):image_index], expected)
                        self.assertEqual(args[image_index + 1], "bash")
                        self.assertFalse((workspace / "should-not-exist").exists())


if __name__ == "__main__":
    unittest.main()
