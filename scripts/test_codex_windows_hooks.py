"""Windows hook launcher regressions; run with python scripts/test_codex_windows_hooks.py."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "codex" / "orfi-run-codex-hook.ps1"


@unittest.skipUnless(os.name == "nt", "native Windows hook transport")
class WindowsHooks(unittest.TestCase):
    def test_windows_overrides_registered(self):
        config = json.loads((ROOT / "codex/hooks.json").read_text(encoding="utf-8"))
        handlers = [h for groups in config["hooks"].values() for group in groups for h in group["hooks"]]
        self.assertEqual(len(handlers), 3)
        for handler in handlers:
            self.assertIn("commandWindows", handler)
            self.assertIn("orfi-run-codex-hook.ps1", handler["commandWindows"])
            self.assertIn("@ORFI_CODEX_HOME@", handler["commandWindows"])

    def run_fixture(self, shell, body, name="enforce-sync", payload=None):
        with tempfile.TemporaryDirectory(prefix="orfi hook test ") as temp:
            directory = Path(temp)
            shutil.copyfile(RUNNER, directory / RUNNER.name)
            if body is not None:
                (directory / ("orfi-kit-" + name + ".sh")).write_text(body, encoding="utf-8", newline="\n")
            return subprocess.run(
                [shell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                 str(directory / RUNNER.name), "-HookName", name],
                input=json.dumps(payload or {"cwd": temp}, ensure_ascii=False),
                capture_output=True, encoding="utf-8", timeout=15,
            )

    def test_stdin_platform_and_unicode(self):
        payload = {"tool_input": {"command": "echo مرحبا"}}
        body = 'printf "platform=%s\\n" "$ORFI_HOOK_PLATFORM" >&2\ncat\n'
        for shell in ("powershell.exe", "pwsh"):
            with self.subTest(shell=shell):
                result = self.run_fixture(shell, body, payload=payload)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), payload)
                self.assertIn("platform=codex", result.stderr)

    def test_denial_json_preserved(self):
        denied = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny"}}
        result = self.run_fixture("powershell.exe", "printf '%s' '" + json.dumps(denied) + "'\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), denied)

    def test_exit_code_and_stderr_preserved(self):
        result = self.run_fixture("powershell.exe", "echo verifier-error >&2\nexit 7\n", "verify-csharp-format")
        self.assertEqual(result.returncode, 7)
        self.assertIn("verifier-error", result.stderr)

    def test_missing_hook_is_error(self):
        result = self.run_fixture("powershell.exe", None)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not found", result.stderr.lower())

    def test_installer_upgrades_without_duplicate_or_foreign_changes(self):
        config = json.loads((ROOT / "codex/hooks.json").read_text(encoding="utf-8"))
        foreign = {"matcher": "^Bash$", "hooks": [{"type": "command", "command": "foreign-owned-hook"}]}
        for groups in config["hooks"].values():
            for group in groups:
                for handler in group["hooks"]:
                    handler.pop("commandWindows", None)
        config["hooks"]["PreToolUse"].insert(0, foreign)
        config["description"] = "user-owned description"
        with tempfile.TemporaryDirectory(prefix="orfi install test ") as temp:
            target = Path(temp) / "hooks.json"
            target.write_text(json.dumps(config), encoding="utf-8")
            script = Path(temp) / "test.ps1"
            script.write_text(r"""
$ErrorActionPreference = 'Stop'
$RepoDir = '__ROOT__'
$Home_ = '__TEMP__'
$ClaudeHooks = Join-Path $Home_ 'hooks'
$CodexHooksJsonSrc = Join-Path $RepoDir 'codex/hooks.json'
$CodexHooksJson = Join-Path $Home_ 'hooks.json'
$tokens = $null; $errors = $null
$tree = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $RepoDir 'install.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
foreach ($function in $tree.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $true)) {
    if ($function.Name -in @('Say','Place','Install-CodexHooks')) { Invoke-Expression $function.Extent.Text }
}
Install-CodexHooks
Install-CodexHooks
""".replace("__ROOT__", ROOT.as_posix()).replace("__TEMP__", Path(temp).as_posix()), encoding="utf-8")
            result = subprocess.run(["pwsh", "-NoProfile", "-File", str(script)], capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            after = json.loads(target.read_text(encoding="utf-8-sig"))
            self.assertEqual(after["description"], "user-owned description")
            self.assertEqual(after["hooks"]["PreToolUse"][0], foreign)
            handlers = [h for groups in after["hooks"].values() for group in groups for h in group["hooks"] if "orfi-kit-" in h["command"]]
            self.assertEqual(len(handlers), 3)
            for handler in handlers:
                self.assertIn("commandWindows", handler)
                self.assertNotIn("@ORFI_CODEX_HOME@", handler["commandWindows"])
            self.assertTrue((Path(temp) / "hooks/orfi-run-codex-hook.ps1").is_file())


    @unittest.skipUnless(shutil.which("jq"), "jq required by Bash installer merge")
    def test_bash_installer_upgrades_without_duplicates(self):
        text = (ROOT / "install.sh").read_text(encoding="utf-8")
        filter_text = text.split("    jq --argjson ins \"$src\" '", 1)[1].split("\n    ' \"$CODEX_HOOKS_JSON\"", 1)[0]
        source = json.loads((ROOT / "codex/hooks.json").read_text(encoding="utf-8"))
        old = json.loads(json.dumps(source))
        for groups in old["hooks"].values():
            for group in groups:
                for handler in group["hooks"]:
                    handler.pop("commandWindows", None)
        foreign = {"hooks": [{"type": "command", "command": "foreign-hook"}]}
        old["hooks"]["PreToolUse"].insert(0, foreign)
        with tempfile.TemporaryDirectory(prefix="orfi jq test ") as temp:
            target = Path(temp) / "hooks.json"
            target.write_text(json.dumps(old), encoding="utf-8")
            for _ in range(2):
                result = subprocess.run(["jq", "--argjson", "ins", json.dumps(source), filter_text, str(target)], capture_output=True, encoding="utf-8", timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                after = json.loads(result.stdout)
                target.write_text(result.stdout, encoding="utf-8")
            self.assertEqual(after["hooks"]["PreToolUse"][0], foreign)
            owned = [h for gs in after["hooks"].values() for g in gs for h in g["hooks"] if "orfi-kit" in h["command"]]
            self.assertEqual(len(owned), 3)
            self.assertTrue(all(h.get("commandWindows") for h in owned))


if __name__ == "__main__":
    unittest.main(verbosity=2)
