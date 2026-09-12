---
name: orfi-kit-persist-state
description: persist state between sessions. 
---

First resolve the **helper-files root**: read `.orfi-kits/helper-files-root` in the current repo. If it is missing, STOP and run `orfi-kit-set-helper-files-root` — ask the user for the absolute path (never search for, infer, or guess a location; no default), then continue. There is no default path — do not fall back to any hard-coded location. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.

Persist current session state to `<kit-root>\CODEX-SESSION-STATE.md` so work can be resumed after clearing context. Be explicit, factual, and include blockers or unresolved risks.