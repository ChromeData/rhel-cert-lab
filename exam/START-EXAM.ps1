# Starts the practice-exam server and opens it in your browser.
# Double-click this, or run it from anywhere.

$ErrorActionPreference = 'Continue'
$examDir = 'C:\Users\SnatchedYourChain\New folder\rhel-cert-lab\exam'
$py      = 'C:\Python314\python.exe'
$url     = 'http://127.0.0.1:8899/'

function Test-Server {
    try { (Invoke-WebRequest $url -TimeoutSec 3 -UseBasicParsing).StatusCode -eq 200 }
    catch { $false }
}

if (Test-Server) {
    Write-Host "Server already running." -ForegroundColor Green
} else {
    Write-Host "Starting exam server..." -ForegroundColor Yellow
    # Hidden on purpose: it has no UI of its own and this is what survives reliably.
    # Terminals it opens go through wt.exe, so they get their own visible window.
    Start-Process -FilePath $py -ArgumentList 'serve.py' -WorkingDirectory $examDir -WindowStyle Hidden
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Milliseconds 600
        if (Test-Server) { break }
    }
    if (Test-Server) { Write-Host "Server up." -ForegroundColor Green }
    else { Write-Host "Server did not come up - run serve.py by hand to see the error." -ForegroundColor Red; exit 1 }
}

# Make sure the lab nodes are running too, or the terminal buttons have nothing to reach.
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (Test-Path $vbm) {
    foreach ($vm in 'rhcsa-node1','rhcsa-node2') {
        $state = ((& $vbm showvminfo $vm --machinereadable 2>$null |
                   Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim()
        if ($state -ne 'running') {
            Write-Host "Starting $vm..." -ForegroundColor Yellow
            & $vbm startvm $vm --type headless | Out-Null
        }
    }
}

Start-Process $url
Write-Host ""
Write-Host "  Exam:  $url" -ForegroundColor Cyan
Write-Host "  Open a task, then click 'Open node1 terminal'." -ForegroundColor DarkGray
Write-Host ""
