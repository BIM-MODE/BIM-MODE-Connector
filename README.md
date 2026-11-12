# BIM-MODE Connector for Revit

Author: BIM-MAN Company.

## Supported build targets

| Revit | Runtime | Build notes |
|---|---|---|
| 2021-2024 | .NET Framework 4.8 | Built against the installed Revit APIs |
| 2025 | .NET 8 | Built against the Revit API reference package |
| 2026 | .NET 8 | Built against the installed Revit APIs |
| 2027 | .NET 10 | Built against the Revit API reference package |

A successful build is not proof that every operation has been tested live in every Revit year.
Revit 2021 lacks native PDF export and ceiling creation APIs. Four bundled handlers
(PDF export and create/bind/remove shared parameters) explicitly report their 2022+
requirement on 2021; floor creation uses the older API. All other operations still
require suitable model content and valid parameters.

## Native tools and compatibility

The existing BIM-MODE native category, element, view, sheet, and documentation tools
remain. There are now **224 bundled native handlers**, with their own real
schemas, running in the selected Revit process without a separate server
or the BIM-MODE Python engine. Apache-2.0 attribution is included.

The old extended catalog is retained for provenance/tests, but its approximate
aliases are no longer registered. Fourteen old gateway/lifecycle aliases are retired.
BIM-MODE provides its own session selection, C# execution,
custom tools, and change-event history below. BIM-MODE does not include a separate
gateway process, history database, failure store, asynchronous operation store,
model-lineage reconciliation, or suggestion-driven baker.

Gateway mode exposes search/describe/call tools. Use bim_search_tools, then
bim_describe_tool, then bim_call_tool. bim_capabilities reports registered
providers and limits; counts do not mean every tool has been live-tested.

## Write and run Revit code

- `bim_validate_csharp`: compile a C# body without executing it.
- `bim_execute_csharp`: compile/run C# on Revit's API thread.
- `bim_bake_tool`: compile and persist a reusable `custom_<name>` tool.
- `bim_list_baked_tools`: list saved tools; invoke them through bim_call_tool.
- `bim_change_history`: recent committed document events, including manual edits
  and undo/redo, with affected element IDs and transaction names.

C# has `uiapp`, `uidoc`, `doc`, and a JsonObject named `args`. Return JSON-serializable
values. Imports include System, LINQ, collections, Revit DB/UI, and JSON nodes.
A transaction is supplied: do not start another top-level transaction.

Example arguments to bim_execute_csharp:

```json
{"code":"return new { title = doc.Title, levels = new FilteredElementCollector(doc).OfClass(typeof(Level)).GetElementCount() };","preview":true}
```

`preview` defaults to true and rolls back model edits. Use false to commit. Errors
roll back the enclosing transaction. Code is full-trust, not a sandbox: filesystem,
network, and other external side effects cannot be rolled back. Running code must
return promptly; there is no safe forced timeout for code already on Revit's UI thread.
Read-only mode blocks execution/baking, and destructive approval applies to both.
Python runs through bundled IronPython 3.4.2 in the same Revit process. Use
`bim_validate_python` to check syntax and `run_python_script` (or
`execute_revit_code`) to run it. Variables are `doc`, `uidoc`, `uiapp`, `__revit__`,
and the Python dictionary `args`; assign JSON-compatible output to `result`.
Preview defaults to true. The runtime is full-trust and cannot safely interrupt
code already running on Revit's API thread. CPython binary packages and newer
Python syntax are not supported. No external Python installation, pyRevit service
or additional MCP server is required.

`bim_engine_health` checks provider catalogs, bundled Python execution and Revit
API responsiveness. The connector no longer registers the external BIM-MODE HTTP
provider or approximate basic aliases. Those basic commands now have local
implementations and explicit input schemas. Specialized workflows from the old
APIAI Python extension are not imported automatically: search the registered
capabilities before relying on a particular legacy workflow. This is an integrated
execution foundation, not a claim that every legacy workflow has been migrated.

Recipes: `%APPDATA%/BIM-MODE/recipes/`. History: `Documents/BIM-MODE/logs/changes-<pid>.jsonl`.
History rotates at 20 MB; it stores change events, not previous geometry snapshots.

## Three concurrent sessions

The add-in claims the first available port from 48890, 48891, 48892 (configurable base).
A fourth process is refused if all three slots are occupied. Discovery is per process,
so one shutdown cannot remove another session's record.

The stdio bridge exposes `bim_list_sessions` and `bim_select_session` (argument `pid`).
With multiple sessions, choose explicitly. Each bridge stays pinned to its selected
PID; if that process closes, it returns an error instead of selecting another model.
You can also launch with `--pid <PID>` or a fixed `--url`.

All active providers execute inside their selected Revit process. The archived
pyRevit route is no longer installed or called by the connector.

## Install (GitHub / gitinstall & npm)

**GitHub one-line install (`gitinstall`):**

```powershell
irm https://raw.githubusercontent.com/BIM-MODE/BIM-MODE-Connector/main/gitinstall.ps1 | iex
```

Or run the downloaded script directly for a specific Revit version (`2021`-`2027`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File gitinstall.ps1 -RevitVersion 2026
```

**npm / npx (`bim-mode-mcp`):**

```powershell
npx github:BIM-MODE/BIM-MODE-Connector --install 2026
```

Once installed, run the MCP bridge via `npx bim-mode-mcp` (or `npx github:BIM-MODE/BIM-MODE-Connector`).

The installer uses a new version folder, backs up the manifest, and takes effect in
a new Revit process. It never closes existing models. The bridge has its own folder
so its .NET 8 core cannot overwrite the .NET Framework core used by older Revit.
Use the ribbon's Connect AI apps feature only for clients you intend to configure.

## Attribution and support

Part of the bundled handler source is Apache-2.0 licensed open-source code. See
LICENSE-APACHE-2.0.txt and THIRD-PARTY-NOTICES.txt. Modified files are marked. No third-party
or Autodesk endorsement or vendor support is included. No comparative performance or reliability
claim against other products has been established.

## Model evidence tools

- `bim_capture_model_snapshot`: persist a scoped instance-data snapshot with unique IDs and selected parameters.
- `bim_compare_model_snapshots`: report additions, removals and changed captured values; reject mismatched scopes.
- `bim_list_model_snapshots`: discover saved snapshots across sessions (latest 100).
- `bim_check_parameter_rule`: required-value, duplicate-value or regex checks returning failing UniqueIds.

These tools do not compare geometry or certify building-code compliance. Parameter names
are exact, localized instance names; numeric values use Revit internal units. Missing
parameters are distinguished from empty values. Capture refuses truncation and ambiguous
parameter names. Snapshot capture writes local files and goes through the write approval
gate, without opening a model transaction.

## Connecting AI apps

The **AI Connector > Connect AI apps** window sets up the following apps with one click (Connect, Reconnect, Remove): Claude Desktop, Claude Code,
Cursor, Windsurf, Gemini CLI, VS Code (Copilot) and Insiders, LM Studio, Kimi (desktop app and Code CLI), Kimi CLI (older), OpenAI Codex,
Google Antigravity, DeepSeek Harness, PawWork and Cline (app, CLI and VS Code extension). ChatGPT and OpenCode have a Setup guide button.
Apps that only run in a browser or offer Google-hosted connectors only (for example the Gemini desktop app) cannot start a local MCP program and
cannot be connected. Restart the AI app (or start a new chat) after connecting.

## Code mode helpers

`bim_run_code` runs one Python script that calls many tools and returns only the answer. Besides `tools.call`, it offers
`tools.recipe('model_summary' | 'qa' | 'coordination' | 'sheets')` (a whole check in one call), `tools.many([[name, args], ...])`,
`tools.pick(rows, 'id', 'name')`, `tools.brief(x, 20)`, `tools.models()`, `tools.links()`, `tools.safe(name, args)` and `tools.help(topic)`.
Results over about 12,000 characters are shortened automatically (pass `full_output=true` to keep everything). There is no default time
limit; `timeout_sec` sets one. Tool-call waits in the apps are set to 24 hours.