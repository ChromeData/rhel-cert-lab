# Opens a root shell on rhcsa-node2. Double-click, or run from anywhere.
$ErrorActionPreference = 'Continue'
$key = Join-Path $PSScriptRoot '.ssh\lab_key'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

$Host.UI.RawUI.WindowTitle = 'RHCSA - node2'

# Make sure the VM is actually up before trying to connect.
$state = ((& $vbm showvminfo rhcsa-node2 --machinereadable 2>$null |
           Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim()
if ($state -ne 'running') {
    Write-Host "Starting rhcsa-node2..." -ForegroundColor Yellow
    & $vbm startvm rhcsa-node2 --type headless | Out-Null
    Start-Sleep -Seconds 40
}

Write-Host ""
Write-Host "  Connecting to node2 (RHCSA practice)" -ForegroundColor Cyan
Write-Host "  tasks: cat /root/TASKS.md    grade: bash /root/grade.sh -v" -ForegroundColor DarkGray
Write-Host ""

ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -p 2202 root@127.0.0.1

Write-Host ""
Write-Host "Session ended. Press any key to close." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
