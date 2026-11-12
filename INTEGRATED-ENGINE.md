# Integrated BIM-MODE engine

The active connector uses one MCP endpoint and runs its registered providers inside
Revit. It no longer discovers or calls the APIAI pyRevit HTTP engine. C# automation,
bundled IronPython, the native Revit tools, and bundled upstream implementations
use that same connection and the existing approval/read-only gates.

## Included in this change

- Local implementations replace the basic catalog's external-service dispatch.
- Python syntax validation and execution are bundled with the add-in. Each execution
  has a fresh scope, captured output capped at 64 KB per stream, and JSON-compatible
  result checking before model changes commit. Preview defaults to rollback.
- `bim_engine_health` checks providers, a fixed Python arithmetic probe, and Revit
  API responsiveness. It reports errors rather than instructing users to reload an
  additional engine.
- The installer archives the obsolete BIM-MODE pyRevit route for recovery.
- The existing PID selection, three-session limit, activity logs, approvals, native
  transaction handling and C# preview behavior remain in use.

## What this does not establish

This does not import every specialized tool from the APIAI extension. Differently
named equivalents need semantic verification, and an exact name does not prove
identical behavior.

IronPython supports its Python 3.4 language/runtime surface, not arbitrary modern
CPython packages. No standard library copied from another installed Python is used.
Scripts are full-trust and must return promptly; running code cannot safely be
forcibly stopped on Revit's API thread. Preview cannot roll back external effects.

Family placement here is limited to non-hosted, level-based families. Other placement
types require their dedicated native tools. Closing documents requires an explicit
non-active document title. Clear colors resets all element overrides in its scope.

## Verification

`build.ps1` runs the automated checks before packaging:

- `tests/BimMode.SchemaTests`: tool catalog declarations and input schemas
  (registration and schemas, not modeling behavior).
- `tests/BimMode.Tests`: runtime, transport, security hardening and client set-up tests.
- `tests/BimMode.PythonSmoke`: the .NET Framework 4.8 IronPython runtime used by
  Revit 2021-2024.

`release.ps1` builds every Revit year, runs those tests, checks the packaged files
and does a sandboxed install/uninstall. None of this exercises a live Revit model:
preview edits and committed edits still need testing on disposable models.
