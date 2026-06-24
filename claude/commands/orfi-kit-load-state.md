---
name: orfi-kit-load-state
description: load state between sessions. 
---

First resolve the **helper-files root**: read `.orfi-kits/helper-files-root` in the current repo. If it is missing, STOP and run `/orfi-kit-set-helper-files-root` — ask the user for the absolute path (never search for, infer, or guess a location; no default), then continue. There is no default path — do not fall back to any hard-coded or relative location. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.

Read the file `<kit-root>\CLAUDE-SESSION-STATE.md`. This is the Claude Code session handoff file — read it in full before doing anything else.