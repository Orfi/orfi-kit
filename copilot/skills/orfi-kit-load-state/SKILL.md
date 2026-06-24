---
name: orfi-kit-load-state
description: load state between sessions. 
---

First resolve the **helper-files root**: read `.orfi-kits/helper-files-root` in the current repo. If it is missing, configure it now via `/orfi-kit-set-helper-files-root` (ask the user for the path, write the pointer), then continue. There is no default path — do not fall back to any hard-coded location. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.

Read `<kit-root>\COPILOT-SESSION-STATE.md` in full before doing anything else in the session.