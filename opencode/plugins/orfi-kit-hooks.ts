/**
 * orfi-kit hooks for opencode.
 *
 * Single source of logic: the SAME bash hooks under ~/.claude/hooks (and, if
 * present, <worktree>/.claude/hooks) that Claude Code and GitHub Copilot run.
 * This plugin is only a transport: it feeds each hook the payload shape it
 * already parses and translates its output into opencode's hook contracts.
 * ORFI_HOOK_PLATFORM=opencode selects opencode's output encoding in the scripts.
 *
 * Wired here:
 *   - enforce-sync      -> tool.execute.before on git push; non-zero exit
 *                          throws and aborts the tool call (same block contract
 *                          as Claude's PreToolUse exit code).
 *   - format verifiers  -> tool.execute.after on write/edit of C# and C/C++
 *                          files; the hook's stdout (a {output:{output}} JSON)
 *                          is merged into the tool result so the model sees the
 *                          violations and must act on them (advisory, like
 *                          Claude's PostToolUse additionalContext).
 *   - conventions       -> experimental.chat.system.transform injects the C# and
 *                          C++ convention loaders' output into the system prompt.
 *
 * Honest gaps versus Claude/Copilot (documented, not papered over):
 *   - No Stop event exists on opencode, so enforce-brevity
 *     (Claude Stop) and verify-skill-contract (Copilot/Claude Stop) have
 *     NO equivalent here. The skill-contract check is instead covered at
 *     review time (docs/skills/code-review) and no brevity enforcement runs.
 *   - tool.execute.before only mutates args / throws; it cannot inject context,
 *     so the conventions loaders are attached to the system prompt instead of
 *     firing per-write like Claude's PreToolUse loaders. Consequently they run
 *     against the worktree root (not the specific file being edited), which is
 *     an approximation for sub-tree configs.
 *   - Requires `bash` on POSIX, or Git Bash on Windows (found via PATH or the
 *     well-known install paths). Without bash the plugin logs a warning and
 *     fails OPEN (a missing runtime must not fake a pass nor silently block).
 */
import { existsSync, readdirSync } from "node:fs"
import path from "node:path"
import os from "node:os"

import type { Plugin } from "@opencode-ai/plugin"

const HOOKS_GLOBAL = path.join(os.homedir(), ".claude", "hooks")

/** Convert a Windows path to the POSIX form Git Bash expects (C:\x -> /c/x). */
function posixPath(p: string): string {
  if (process.platform !== "win32") return p
  const m = p.match(/^([A-Za-z]):[\\/](.*)$/)
  if (m) return `/${m[1].toLowerCase()}/${m[2].replace(/\\/g, "/")}`
  return p
}

/** Resolve bash: PATH on POSIX; Git Bash candidates first on Windows. */
function bashBin(): string {
  if (process.platform === "win32") {
    const candidates: string[] = []
    if (process.env.ProgramFiles) candidates.push(path.join(process.env.ProgramFiles, "Git", "bin", "bash.exe"))
    if (process.env["ProgramFiles(x86)"])
      candidates.push(path.join(process.env["ProgramFiles(x86)"], "Git", "bin", "bash.exe"))
    if (process.env.LOCALAPPDATA)
      candidates.push(path.join(process.env.LOCALAPPDATA, "Programs", "Git", "bin", "bash.exe"))
    for (const c of candidates) if (existsSync(c)) return c
  }
  return "bash"
}

export const OrfiKitHooks: Plugin = async ({ worktree, client }) => {
  const bash = bashBin()
  const hooksDir = resolveHooksDir(worktree)
  if (!hooksDir) {
    await log(client, "warn", "orfi-kit hooks not found (looked in <worktree>/.claude/hooks and ~/.claude/hooks) — plugin inactive")
  } else {
    await log(client, "info", `orfi-kit: ${bash} @ ${hooksDir}`)
  }

  return {
    "tool.execute.before": async (input, output) => {
      if (!hooksDir) return
      const command: unknown = (output.args as Record<string, unknown> | undefined)?.command
      if (typeof command !== "string" || !command.includes("git push")) return
      const res = await runHook(hooksDir, bash, "orfi-kit-enforce-sync.sh", {
        tool_input: { command },
        cwd: posixPath(worktree ?? process.cwd()),
      }, worktree ?? process.cwd())
      if (res.exitCode !== 0) {
        throw new Error(res.stdout.trim() || res.stderr.trim() || "push blocked by orfi-kit-enforce-sync")
      }
    },

    "tool.execute.after": async (input, output) => {
      if (!hooksDir) return
      const filePath: unknown = (input.args as Record<string, unknown> | undefined)?.filePath
      if (typeof filePath !== "string") return
      const hookName = hookForFile(filePath)
      if (!hookName) return
      const res = await runHook(hooksDir, bash, hookName, {
        tool_input: { file_path: posixPath(filePath) },
      }, worktree ?? process.cwd())
      const text = parseOpenCodeOutput(res.stdout)
      if (!text) return
      output.output = output.output ? `${output.output}\n${text}` : text
    },

    "experimental.chat.system.transform": async (_input, output) => {
      if (!hooksDir) return
      const cwd = worktree ?? process.cwd()
      const blocks = await loadConventions(hooksDir, bash, posixPath(cwd), cwd)
      for (const block of blocks) output.system.push(...block.split("\n"))
    },
  }
}

function resolveHooksDir(worktree: string | undefined): string | null {
  // Prefer the project's .claude/hooks ONLY when it actually holds the orfi-kit
  // scripts — a bare dir (e.g. one that only has a state/ subfolder) must fall
  // back to the global install rather than run scripts from the wrong place.
  if (worktree) {
    const local = path.join(worktree, ".claude", "hooks")
    if (existsSync(local) && containsOrfiHooks(local)) return local
  }
  if (existsSync(HOOKS_GLOBAL)) return HOOKS_GLOBAL
  return null
}

function containsOrfiHooks(dir: string): boolean {
  try {
    return readdirSync(dir).some((n) => n.startsWith("orfi-kit-") && n.endsWith(".sh"))
  } catch {
    return false
  }
}

function hookForFile(p: string): string | null {
  if (p.endsWith(".cs") && !/[.](g|designer|generated)\.cs$/.test(p) && !p.includes("Migrations")) {
    return "orfi-kit-verify-csharp-format.sh"
  }
  if (/[.](cpp|hpp|cc|cxx|inl)$/.test(p)) return "orfi-kit-verify-cpp-format.sh"
  return null
}

/** Parse the {output:{output}} JSON the scripts emit under ORFI_HOOK_PLATFORM=opencode. */
function parseOpenCodeOutput(stdout: string): string | null {
  if (!stdout.trim()) return null
  try {
    const parsed = JSON.parse(stdout) as { output?: { output?: string } }
    const text = parsed.output?.output
    return typeof text === "string" && text.trim() ? text : null
  } catch {
    return stdout.trim() || null
  }
}

async function runHook(
  hooksDir: string,
  bash: string,
  name: string,
  payload: unknown,
  cwd: string,
): Promise<{ exitCode: number; stdout: string; stderr: string }> {
  const hookPath = path.join(hooksDir, name)
  const proc = Bun.spawn([bash, posixPath(hookPath)], {
    cwd,
    env: { ...process.env, ORFI_HOOK_PLATFORM: "opencode" },
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
  })
  proc.stdin.write(JSON.stringify(payload))
  proc.stdin.end()
  const stdout = await new Response(proc.stdout).text()
  const stderr = await new Response(proc.stderr).text()
  const exitCode = await proc.exited
  return { exitCode, stdout, stderr }
}

/** Cached per worktree; TTL 1h so a mid-session config change is eventually picked up. */
const conventionsCache = new Map<string, { at: number; blocks: string[] }>()

async function loadConventions(
  hooksDir: string,
  bash: string,
  rootPosix: string,
  spawnCwd: string,
): Promise<string[]> {
  const cached = conventionsCache.get(rootPosix)
  if (cached && Date.now() - cached.at < 60 * 60 * 1000) return cached.blocks
  const blocks: string[] = []
  const probeFile = (name: string): string =>
    rootPosix.endsWith("/") ? `${rootPosix}${name}` : `${rootPosix}/${name}`
  for (const probe of [
    { loader: "orfi-kit-load-csharp-conventions.sh", file: probeFile("orfi-kit-probe.cs") },
    { loader: "orfi-kit-load-cpp-conventions.sh", file: probeFile("orfi-kit-probe.cpp") },
  ]) {
    const res = await runHook(hooksDir, bash, probe.loader, {
      tool_input: { file_path: probe.file },
    }, spawnCwd)
    if (!res.stdout) continue
    // Only surface real guidance: a found config ("--- <path>") or the shipped
    // baseline. "Repo encodes NOTHING / not installed" is default behaviour
    // already, so it is not injected as system noise.
    if (/--- |ENFORCING the orfi-kit baseline/.test(res.stdout)) blocks.push(res.stdout)
  }
  conventionsCache.set(rootPosix, { at: Date.now(), blocks })
  return blocks
}

async function log(client: unknown, level: string, message: string): Promise<void> {
  try {
    const c = client as { app?: { log?: (input: unknown) => Promise<unknown> } }
    await c.app?.log?.({ body: { service: "orfi-kit-hooks", level, message } })
  } catch {
    // Logging must never break hooking.
  }
}