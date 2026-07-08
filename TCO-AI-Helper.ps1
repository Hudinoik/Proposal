# TCO AI Helper (Windows) - lets the TCO Agreement Generator draft with YOUR
# Claude subscription (no API key).
#
# It listens on this computer only (http://127.0.0.1:8765). When you click
# "Draft with Claude" in the app, the app hands the notes to this helper, and
# the helper asks Claude through the Claude Code command ("claude"), which is
# signed in with your Claude account.
#
# One-time setup:
#   1. Install Claude Code from https://claude.ai/download and sign in once.
#   2. Double-click "Start TCO AI Helper.bat" and leave the window open.

$Port = 8765
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Find-Claude {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $guess = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
    if (Test-Path $guess) { return $guess }
    return $null
}

function Invoke-Claude([string]$Prompt) {
    $exe = Find-Claude
    if (-not $exe) {
        return @{ ok = $false; error = "Claude Code is not installed (command 'claude' not found). Install it from https://claude.ai/download and sign in once." }
    }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = "-p --output-format text"
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
        $proc = [System.Diagnostics.Process]::Start($psi)
        $writer = New-Object System.IO.StreamWriter($proc.StandardInput.BaseStream, (New-Object System.Text.UTF8Encoding($false)))
        $writer.Write($Prompt); $writer.Close()
        $errTask = $proc.StandardError.ReadToEndAsync()
        $out = $proc.StandardOutput.ReadToEnd()
        if (-not $proc.WaitForExit(300000)) { $proc.Kill(); return @{ ok = $false; error = "Claude took too long to answer. Try again." } }
        if ($proc.ExitCode -ne 0) {
            $e = $errTask.Result
            if (-not $e) { $e = "claude exited with an error" }
            return @{ ok = $false; error = $e.Substring(0, [Math]::Min(400, $e.Length)) }
        }
        return @{ ok = $true; text = $out }
    } catch {
        return @{ ok = $false; error = "Could not run Claude Code: $($_.Exception.Message)" }
    }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
try { $listener.Start() } catch {
    Write-Host "Could not start on port $Port - is the helper already running in another window?"
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "TCO AI Helper is running at http://127.0.0.1:$Port"
Write-Host "It only accepts connections from this computer."
Write-Host "It drafts using YOUR Claude subscription via Claude Code ('claude')."
Write-Host "Leave this window open while you use the TCO Agreement Generator."
Write-Host "Press Ctrl+C to stop."

function Send-Json($ctx, [int]$code, $obj) {
    $body = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress))
    $r = $ctx.Response
    $r.StatusCode = $code
    $r.Headers.Add("Access-Control-Allow-Origin", "*")
    $r.Headers.Add("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
    $r.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $r.ContentType = "application/json"
    $r.ContentLength64 = $body.Length
    $r.OutputStream.Write($body, 0, $body.Length)
    $r.OutputStream.Close()
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        if ($req.HttpMethod -eq "OPTIONS") {
            $r = $ctx.Response
            $r.StatusCode = 204
            $r.Headers.Add("Access-Control-Allow-Origin", "*")
            $r.Headers.Add("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
            $r.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
            $r.OutputStream.Close()
            continue
        }
        if ($req.HttpMethod -eq "GET" -and $req.Url.AbsolutePath -eq "/health") {
            Send-Json $ctx 200 @{ ok = $true; service = "tco-ai-helper" }
            continue
        }
        if ($req.HttpMethod -eq "POST" -and $req.Url.AbsolutePath -eq "/draft") {
            $reader = New-Object System.IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
            $prompt = $reader.ReadToEnd(); $reader.Close()
            if (-not $prompt.Trim()) { Send-Json $ctx 400 @{ ok = $false; error = "empty prompt" }; continue }
            Write-Host "  ... drafting with Claude (this can take up to a minute)"
            $res = Invoke-Claude $prompt
            if ($res.ok) { Write-Host "  OK draft returned to the app"; Send-Json $ctx 200 $res }
            else { Write-Host ("  X " + $res.error); Send-Json $ctx 500 $res }
            continue
        }
        Send-Json $ctx 404 @{ ok = $false; error = "not found" }
    } catch {
        # keep serving
    }
}
