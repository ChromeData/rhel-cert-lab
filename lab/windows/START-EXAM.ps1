<#
.SYNOPSIS
    Starts the full RHCSA exam simulation.

.DESCRIPTION
    Boots the three VMs and opens the exam console window. That window IS your exam:
    Firefox shows the tasks and countdown timer, and the dash has terminals into the
    two systems under test.

.EXAMPLE
    .\START-EXAM.ps1
    .\START-EXAM.ps1 -Fresh      # roll node1/node2 back to a clean slate first
#>
[CmdletBinding()]
param([switch]$Fresh)

$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
function State { param($vm)
  ((& $vbm showvminfo $vm --machinereadable 2>$null | Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim() }

if ($Fresh) {
    Write-Host "`nResetting the systems under test to clean-install..." -ForegroundColor Yellow
    foreach ($vm in 'rhcsa-node1','rhcsa-node2') {
        if ((State $vm) -eq 'running') { & $vbm controlvm $vm poweroff 2>&1 | Out-Null; Start-Sleep 3 }
        & $vbm snapshot $vm restore clean-install 2>&1 | Out-Null
        Write-Host "  $vm reset" -ForegroundColor DarkGray
    }
    Write-Host "  Also clear the timer: click Restart in the exam paper.`n" -ForegroundColor DarkGray
}

# Systems under test first, so they are up before the console tries to reach them.
foreach ($vm in 'rhcsa-node1','rhcsa-node2') {
    if ((State $vm) -ne 'running') { & $vbm startvm $vm --type headless 2>&1 | Out-Null }
    Write-Host "  $vm running" -ForegroundColor DarkGray
}
Start-Sleep -Seconds 5
if ((State 'rhcsa-console') -ne 'running') { & $vbm startvm rhcsa-console --type gui 2>&1 | Out-Null }
Write-Host "  rhcsa-console starting (window opening)" -ForegroundColor DarkGray

Write-Host @"

=== EXAM READY ===

  The console window is your exam screen. It logs in automatically and
  Firefox opens the exam paper. Set your time limit, click Begin Exam.

  In the dash at the bottom of the console:
    Exam Paper        tasks + countdown timer
    Terminal - node1  the system you configure
    Terminal - node2  second system, for testing services from outside

  When time is up, in the node1 terminal:
    bash /root/grade.sh -v        (grade2/3/4 for the other exams)
    reboot
    bash /root/grade.sh -v        <- this second run is the real score

  Passing is 70%, same as the real exam (210/300).

"@ -ForegroundColor Cyan
