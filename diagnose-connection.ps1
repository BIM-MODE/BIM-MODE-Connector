# BIM-MODE - connection diagnosis. Run:  powershell -ExecutionPolicy Bypass -File diagnose-connection.ps1
# Prints PASS/FAIL per step with the fix, and saves the report to your Desktop (send that file to support).
$ErrorActionPreference='Continue'; $out=New-Object Collections.Generic.List[string]
function Say($ok,$what,$fix=''){ $t= if($ok -eq $true){'PASS'}elseif($ok -eq $false){'FAIL'}else{'INFO'}; $l="[$t] $what"; if($ok -eq $false -and $fix){$l+="`n       -> $fix"}; $out.Add($l); Write-Host $l -ForegroundColor $(if($ok -eq $true){'Green'}elseif($ok -eq $false){'Red'}else{'Gray'}) }
$loc=Join-Path $env:LOCALAPPDATA 'BIM-MODE'
Say $null "Windows $([Environment]::OSVersion.Version)  PowerShell $($PSVersionTable.PSVersion)  user '$env:USERNAME'"

# 1 Revit + add-in
$rv=@(Get-Process Revit -ErrorAction SilentlyContinue); Say ($rv.Count -gt 0) "Revit running ($($rv.Count) process)" 'Start Revit and open any model.'
$manifests=@(Get-ChildItem "$env:APPDATA\Autodesk\Revit\Addins\*\BIM-MODE.addin" -ErrorAction SilentlyContinue)  # active manifests only (older versioned folders are ignored)
Say ($manifests.Count -gt 0) "Add-in manifest installed: $($manifests.FullName -join '; ')" 'Run install.ps1 -RevitVersion <your year>, then restart Revit.'
foreach($m in $manifests){ $asm=(Select-String $m.FullName -Pattern '<Assembly>(.*)</Assembly>').Matches[0].Groups[1].Value; $full=Join-Path $m.DirectoryName $asm
  Say (Test-Path $full) "Add-in DLL exists: $full" 'Re-run install.ps1; the manifest points at a folder that is missing.' }
$rev=@($rv|%{ try{ ($_.Modules|?{$_.ModuleName -like 'BimMode.Addin*'}).FileName }catch{} })|?{$_}
Say ($rev.Count -gt 0 -or $rv.Count -eq 0) "Add-in loaded inside Revit: $($rev -join '; ')" 'Revit showed an unsigned add-in prompt? Choose Always Load. Then check the BIM-MODE ribbon tab exists.'

# 2 server
$token=$null; if(Test-Path "$loc\token.txt"){ $token=(Get-Content "$loc\token.txt" -Raw).Trim() }
Say ($null -ne $token) "Token file exists" 'Start Revit once with the add-in; it creates the token.'
$sess=@(Get-ChildItem $loc -Filter 'session-*.json' -ErrorAction SilentlyContinue)
Say ($sess.Count -gt 0) "Server session files: $($sess.Name -join ', ')" 'The Server button on the BIM-MODE ribbon must be ON (or Settings AutoStart).'
foreach($f in $sess){ $d=Get-Content $f.FullName -Raw|ConvertFrom-Json; $alive=[bool](Get-Process -Id $d.Pid -ErrorAction SilentlyContinue)
  if(-not $alive){ Say $null "stale session file for closed Revit pid $($d.Pid) (ignored)"; continue }
  # Send the token only to this PC (127.0.0.1), the same rule the bridge applies to session files.
  $u=$null; if(-not [uri]::TryCreate([string]$d.Url,'Absolute',[ref]$u) -or $u.Host -ne '127.0.0.1'){ Say $false "session file $($f.Name) has a non-local URL '$($d.Url)' (ignored, token not sent)" 'Delete that session file; only Revit on this PC should write it.'; continue }
  try{ $h=@{Authorization="Bearer $token"}
    $r=Invoke-WebRequest -UseBasicParsing -DisableKeepAlive -Uri $d.Url -Method Post -Headers $h -ContentType 'application/json' -TimeoutSec 10 -Body '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"diagnose","version":"1"}}}'
    $h['Mcp-Session-Id']=[string](@($r.Headers['Mcp-Session-Id'])[0])
    $t=Invoke-WebRequest -UseBasicParsing -DisableKeepAlive -Uri $d.Url -Method Post -Headers $h -ContentType 'application/json' -TimeoutSec 30 -Body '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    $n=@(($t.Content|ConvertFrom-Json).result.tools).Count; Say $true "Revit pid $($d.Pid) answers on $($d.Url) ($n tools listed to an unknown client)"
  }catch{ Say $false "Revit pid $($d.Pid) not reachable on $($d.Url): $($_.Exception.Message)" 'Firewall/antivirus blocking localhost, or token mismatch (restart Revit).' } }

# 3 bridge
$bridge=Join-Path $loc 'bridge\BimMode.Bridge.exe'
if(-not (Test-Path $bridge)){ $bridge=$null; foreach($m in $manifests){ $asm=(Select-String $m.FullName -Pattern '<Assembly>(.*)</Assembly>').Matches[0].Groups[1].Value; $cand=Join-Path (Split-Path (Join-Path $m.DirectoryName $asm)) 'bridge\BimMode.Bridge.exe'; if(Test-Path $cand){ $bridge=$cand } } }
Say ($bridge -and (Test-Path $bridge)) "Bridge exe: $bridge" 'Start Revit once (it copies the bridge), or re-run install.ps1.'
if($bridge -and (Test-Path $bridge)){
  Say $null ("Bridge size {0} MB ({1})" -f [math]::Round((Get-Item $bridge).Length/1MB,1), $(if((Get-Item $bridge).Length -gt 20MB){'self-contained: no .NET needed'}else{'OLD framework-dependent build: needs .NET 8 runtime - install the latest BIM-MODE build'}))
  try{ $psi=New-Object Diagnostics.ProcessStartInfo $bridge; $psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.UseShellExecute=$false
    $p=[Diagnostics.Process]::Start($psi); $p.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"diagnose","version":"1"}}}')
    $e=$p.StandardError.ReadToEndAsync(); $w=$p.StandardOutput.ReadLineAsync(); $ok=$w.Wait(20000)
    Say ($ok -and $w.Result -match 'bimmode') "Bridge starts and speaks MCP$(if(-not $ok){' (no reply in 20 s - antivirus scanning the exe?)'})" 'If a message about .NET appeared: install the latest BIM-MODE build (self-contained). If nothing: allow BimMode.Bridge.exe in antivirus/SmartScreen.'
    try{$p.Kill()}catch{}; if(-not $ok -and $e.Wait(2000)){ Say $null "bridge stderr: $($e.Result)" } }catch{ Say $false "Bridge cannot start: $($_.Exception.Message)" 'Right-click the exe > Properties > Unblock; or allow it in antivirus.' } }

# 4 AI apps
$home2=$env:USERPROFILE; $apps=[ordered]@{
 'Claude Desktop (Store)'=@(Get-ChildItem "$env:LOCALAPPDATA\Packages" -Filter 'Claude_*' -ErrorAction SilentlyContinue|%{ Join-Path $_.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json' })
 'Claude Desktop (classic)'=@("$env:APPDATA\Claude\claude_desktop_config.json")
 'Claude Code'=@("$home2\.claude.json"); 'Cursor'=@("$home2\.cursor\mcp.json"); 'VS Code'=@("$env:APPDATA\Code\User\mcp.json")
 'Windsurf'=@("$home2\.codeium\windsurf\mcp_config.json"); 'Gemini CLI'=@("$home2\.gemini\settings.json"); 'LM Studio'=@("$home2\.lmstudio\mcp.json"); 'Codex'=@("$home2\.codex\config.toml") }
foreach($k in $apps.Keys){ foreach($cfg in $apps[$k]){ if(-not (Test-Path $cfg)){ continue }
  $txt=Get-Content $cfg -Raw; if($txt -notmatch 'bim-mode'){ Say $null "$k : config found, no bim-mode entry yet ($cfg)"; continue }
  $m=[regex]::Match($txt,'[A-Za-z]:(\\\\|\\|/)[^"'']*BimMode\.Bridge\.exe'); $path=($m.Value -replace '\\\\','\')
  Say ($m.Success -and (Test-Path $path)) "$k : bim-mode configured -> $path" "The configured bridge path is missing. In Revit: BIM-MODE > Connect AI apps > Connect (then fully quit and reopen $k)." } }

# 5 recent Claude MCP log errors
$logs=@(Get-ChildItem "$env:LOCALAPPDATA\Packages\Claude_*\LocalCache\Roaming\Claude\logs","$env:APPDATA\Claude\logs" -Filter 'mcp-server-bim-mode*.log' -ErrorAction SilentlyContinue)
foreach($l in $logs){ $e=@(Get-Content $l.FullName -Tail 400|?{$_ -match '\[error\]|Invalid result|spawn|ENOENT|EPERM'}|Select-Object -Last 4); Say ($e.Count -eq 0) "Claude log $($l.Name): $(if($e.Count){'recent errors below'}else{'no recent errors'})" 'Send this report to support.'; $e|%{$out.Add("       $_")} }

$rp=Join-Path ([Environment]::GetFolderPath('Desktop')) 'BIM-MODE-diagnosis.txt'; $out | Set-Content $rp -Encoding UTF8; Write-Host "`nReport saved: $rp" -ForegroundColor Cyan
