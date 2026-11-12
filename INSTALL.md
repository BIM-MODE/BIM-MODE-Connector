# Install BIM-MODE (Revit 2021-2027)

1. Choose a year for which Revit is installed. Binaries are in `dist/<year>/`.
2. Run `powershell -ExecutionPolicy Bypass -File install.ps1 -RevitVersion 2026`
   (replace 2026 as needed). The installer keeps a manifest backup and deploys into
   a fresh folder. Existing Revit processes retain their already loaded version.
3. Open a new Revit process. Review Revit's unsigned-add-in prompt yourself.
4. Open a disposable test model. Check the BIM-MODE ribbon and server status.
5. Configure your intended MCP client to run the `bridge/BimMode.Bridge.exe` inside
   the installed BIM-MODE folder, or use the Connect AI apps ribbon action.
6. In the MCP client, list sessions and select a PID. Use bim_status and
   bim_capabilities and bim_engine_health, then validate and preview a small script before committing.

Default ports: 48890-48892. Token: `%LOCALAPPDATA%/BIM-MODE/token.txt`.
Discovery: `%LOCALAPPDATA%/BIM-MODE/session-<pid>.json`.
Settings: `%APPDATA%/BIM-MODE/settings.json`.

All tools registered by this version run inside the selected Revit process.
The Python runtime is included. No separate MCP or pyRevit service is needed.
The installer archives the obsolete BIM-MODE.extension route if present; other
pyRevit extensions are untouched. Existing specialized APIAI workflows are not
automatically imported into this connector.

To restore an earlier version, close the affected Revit test process when safe,
restore the saved BIM-MODE.addin manifest backup, then launch Revit again. Do not
remove folders whose DLLs are still used by a running Revit process.

Compilation and automated transport tests do not establish that every Revit operation
works in every year. Read README.md for remaining version limitations.


## If an AI app cannot connect (read this first)

1. **Nothing else to install.** The bridge (`bridge/BimMode.Bridge.exe`) is self-contained; it does not need .NET.
   (Builds older than this note needed a .NET 8 runtime on the PC and failed silently without it.)
2. Install the **newest** build. Older builds exposed tools with invalid schemas; Claude, Gemini and ChatGPT/Codex
   reject the whole server when even one tool schema is invalid.
3. Revit shows an *unsigned add-in* prompt on first start: choose **Always Load**.
4. In Revit open **BIM-MODE > Connect AI apps**, press **Connect** for the app, then **fully quit and reopen the AI app**
   (Claude Desktop: tray icon > Quit). The row shows **Connected** once the app talks to Revit.
5. Still stuck? Run `powershell -ExecutionPolicy Bypass -File diagnose-connection.ps1` and send the report it saves
   to your Desktop (`BIM-MODE-diagnosis.txt`). It names the exact failing step.

**Which tools does each app see?** Claude apps get all ~900 tools (they load tools on demand). Every other app
(ChatGPT/Codex, Gemini CLI, Cursor, Copilot, Windsurf, LM Studio...) gets about 20 tools: the always-on core tools plus
`bim_search_tools`, `bim_describe_tool` and `bim_call_tool`, which reach all ~900 tools by name. Reason: ~900 tool
schemas are ~130K tokens and exceed hard limits (Cursor 40, Windsurf 100, Copilot 128). Override in
`%APPDATA%\BIM-MODE\settings.json`: `"exposure": "auto"` (default), `"full"` or `"gateway"`.

**Several models / several Revit windows from one prompt:** add `target_models: ["all"]` to any tool for every open model in
one Revit; add `revit_sessions: "all"` to run it in every running Revit window at the same time.

**"Couldn't attach connectors ... more than 500 tools" (Claude cloud/background tasks).** Claude refuses a local MCP server that lists over 500 tools, so `exposure: auto` lists at most `maxListedTools` (default 480: core tools, then all read-only tools). Every other tool is still reachable by name through `bim_search_tools` / `bim_call_tool`. Set `"exposure": "full"` to list all ~916 (works in chat and Claude Code, but cloud tasks will refuse it).

**Approval button.** `Approval: ON` = Revit asks before an AI changes the model; `Approval: off` = it never asks. Read-only is a separate toggle. Deletes and purges count as ordinary writes. The question is a non-blocking window that auto-denies after 90 s, so Revit never freezes waiting for it.

**Warning policy.** When Revit raises warnings (not errors) while a write tool commits, `"warningPolicy": "accept-and-log"` (default) clears them and lists them in the result as `accepted_warnings`; `"rollback"` undoes the write and names the warnings. Environment variable `BIMMODE_WARNING_POLICY` overrides the file. Edits to `settings.json` take effect on the next call, no Revit restart needed.

## Token and accuracy controls

Settings in `%APPDATA%\BIM-MODE\settings.json` (changes apply to the next call; each can also be left at its default):

| Setting | Default | What it does |
|---|---|---|
| `exposure`, `maxListedTools` | `auto`, 480 | What the tool list costs. Claude apps get up to 480 tools (core + all read tools); every other app gets about 30 and reaches the rest with `bim_search_tools`, `bim_describe_tool`, `bim_call_tool`. Descriptions in the list are short; `bim_describe_tool` returns the full text. |
| `slimResults` | `true` | Removes null fields from results (a missing field means no value). |
| `maxResultChars` | `30000` | About 7,000 tokens per result. A longer list is cut to fit, stays valid JSON and carries `_truncated` ("returned X of Y") so a model cannot mistake it for the whole list. `0` = unlimited. |
| `strictArguments` | `writes` | Misspelled argument names that match a declared one (`levelId` for `level_id`) are repaired. For write tools an invented or missing argument is refused before anything runs, naming the valid ones. `all` does the same for read tools, `off` only repairs. |
| `warningPolicy` | `accept-and-log` | Revit warnings during a write are listed as `accepted_warnings`; `rollback` undoes the write instead. |

`bim_context` is one cheap call that returns the open models, the active model, view and level, the selection count and the current limits, so a model does not have to guess. The server instructions tell models never to invent ids or names, to treat `_truncated` as incomplete, and to fix the cause of an error instead of retrying. The activity log marks calls with `args-repaired`, `bad-args` and `truncated`, so you can count how often a model got something wrong.