# Opens a root shell on rhcsa-node1. Double-click, or run from anywhere.
$ErrorActionPreference = 'Continue'
$key = Join-Path $PSScriptRoot '.ssh\lab_key'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

$Host.UI.RawUI.WindowTitle = 'RHCSA - node1'

# Make sure the VM is actually up before trying to connect.
$state = ((& $vbm showvminfo rhcsa-node1 --machinereadable 2>$null |
           Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim()
if ($state -ne 'running') {
    Write-Host "Starting rhcsa-node1..." -ForegroundColor Yellow
    & $vbm startvm rhcsa-node1 --type headless | Out-Null
    Start-Sleep -Seconds 40
}

Write-Host ""
Write-Host "  Connecting to node1 (RHCSA practice)" -ForegroundColor Cyan
Write-Host "  tasks: cat /root/TASKS.md    grade: bash /root/grade.sh -v" -ForegroundColor DarkGray
Write-Host ""

ssh -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -p 2201 root@127.0.0.1

Write-Host ""
Write-Host "Session ended. Press any key to close." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
