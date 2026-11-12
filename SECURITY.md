# BIM-MODE – Security and Deployment

## Reporting a vulnerability
Please report security problems privately through the repository's **Security → Report a vulnerability**
page (GitHub private vulnerability reporting), not in a public issue. Include the BIM-MODE version, the
Revit year and the steps to reproduce.

## What protects every installation
- **Local only.** The server listens on 127.0.0.1 (this PC). Nothing on the network can reach it.
- **Token.** Every request needs a 256-bit random token (compared in constant time), stored in
  `%LOCALAPPDATA%\BIM-MODE\token.txt` inside the Windows user's own profile.
- **Browser guard.** Requests with a foreign Host or Origin header are refused, so a web page cannot call
  Revit (DNS-rebinding and cross-site requests are blocked).
- **Limits.** Connection, session and request-size caps; slow clients are disconnected.
- **Full-trust code is OFF by default.** `bim_execute_csharp`, `bim_bake_tool`, `custom_*`,
  `run_python_script`, `execute_revit_code` and `acad_run_command` are refused unless
  `"allowFullTrustCode": true` is set.
- **Network paths are blocked.** Tools that open, link, load or export files refuse `\\server\share\...`
  paths, because opening one sends your Windows credentials to that server. Mapped drive letters work.
  Administrators can allow specific file servers with the `BIMMODE_ALLOWED_UNC_HOSTS` environment variable
  (comma separated, e.g. `fileserver,nas01.corp.local`). WebDAV paths (`\\host@SSL\...`) are always refused.
- **Every write is one Revit transaction.** On error it is rolled back; every AI call is written to the
  activity log, with secret-looking arguments (tokens, passwords, client secrets) masked.
- **Approval shows the code.** With approval on, code-running tools show their full code before you allow
  them, and they never offer "allow until Revit closes".

## Know the limits
- **Code mode (`bim_run_code`) is not a security sandbox.** It refuses imports outside a small allowlist
  (`os`, `clr`, `System` and others are blocked) and has call and output limits, but it runs inside the Revit
  process, where determined code can reach .NET. Treat it as trusted code.
- **Prompt injection.** An AI assistant can be steered by text it reads: inside a model, a schedule, a linked
  file or a web page. Everything the AI may do, injected instructions may also try to do. Turn on
  `approval: "writes"` (or `readOnly`) on machines that open untrusted models or browse the web.
- **The AI app sees your model data.** Anything a tool returns is sent to the AI provider you connected.

## Settings a user controls (`%APPDATA%\BIM-MODE\settings.json`)
| Key | Default | Meaning |
|---|---|---|
| `approval` | `"off"` | `"writes"` = Revit asks before each AI change (ribbon: Full Access off) |
| `readOnly` | `false` | `true` = AI may only read |
| `allowFullTrustCode` | `false` | `true` = allow the unrestricted C#/Python runners and AutoCAD command strings |

## IT policy (enforced, users cannot change it)
Copy `policy.template.json` (in the release ZIP; `policy.json` in the source) to
`C:\ProgramData\BIM-MODE\policy.json` (administrator rights needed to write there). Any key it contains
overrides the user's settings at every start: `readOnly`, `approval`, `allowFullTrustCode`, `exposure`,
`disabledTools`. `bim_status` shows `it_policy: true` when it is active. The template ships with
`approval: "writes"`.

## Code signing (removes the "Unsigned Add-In" prompt)
1. Obtain a code-signing certificate from your company CA or a public CA.
2. Build with `$env:BIMMODE_SIGN_THUMBPRINT = "<thumbprint>"` (optional `BIMMODE_TIMESTAMP_URL`). The build
   signs every BIM-MODE DLL and the bridge EXE (SHA-256, timestamped) and stops if signing fails.
3. Deploy the certificate's publisher to **Trusted Publishers** on user PCs (Group Policy). Revit then loads
   the add-in without asking.

Unsigned builds still work; Revit asks once per PC because the add-in installs to one fixed folder.

## Recommended deployment profile
- Standard users: `approval: "writes"`, `allowFullTrustCode: false`.
- Restricted / client-review PCs, or PCs that open models from outside the company: `readOnly: true`.
- Developers only: `allowFullTrustCode: true`.
