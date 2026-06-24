---
name: orfi-kit-persist-state
description: persist state between sessions. 
---

First resolve the **helper-files root**: read `.orfi-kits/helper-files-root` in the current repo. If it is missing, configure it now via `/orfi-kit-set-helper-files-root` (ask the user for the path, write the pointer), then continue. There is no default path — do not fall back to any hard-coded or relative location. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.

Persist your current state in `<kit-root>\CLAUDE-SESSION-STATE.md` so that we can clear and resume. Remember, never panic or introduce code hacks that break the code base, older unit tests or integration tests! Never lie about anything and be transparent.