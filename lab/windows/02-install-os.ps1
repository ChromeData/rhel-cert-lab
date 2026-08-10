<#
.SYNOPSIS
    Installs Rocky Linux 10 onto both lab VMs, completely unattended.

.DESCRIPTION
    1. Generates an SSH keypair for the host -> guest file pushes
    2. Builds a tiny ISO labelled OEMDRV holding ks.cfg (Anaconda auto-detects that
       label and runs the kickstart with zero interaction)
    3. Attaches it, adds NAT port-forwards for SSH
    4. Boots both VMs headless and waits for them to power off (= install finished)
    5. Detaches the kickstart media, sets the VMs to boot from disk
    6. Boots them again and waits for SSH
    7. Pushes TASKS.md / grade.sh / ANSWERS.md onto node1 and snapshots both

    Total unattended time: roughly 15-30 minutes. Nothing to click.

.EXAMPLE
    .\02-install-os.ps1
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$LabRoot     = $PSScriptRoot,
    # Rocky/RHEL 9 ONLY. RHEL 10 needs x86-64-v3, which VirtualBox cannot expose while
    # Windows VBS (Memory Integrity) is enabled - it dies before the installer starts.
    [string]$IsoPath     = 'E:\RHCSA-Lab\iso\Rocky-9.8-x86_64-dvd.iso',
    [int]$InstallTimeoutMin = 45,
    [switch]$SkipInstall     # jump straight to the post-install steps
)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbm)) { throw "VBoxManage not found at $vbm" }

function Say  { param($m) Write-Host "  -> $m" -ForegroundColor DarkGray }
function Head { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Good { param($m) Write-Host "  OK: $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  !!  $m" -ForegroundColor Yellow }

function VBox {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $o = & $vbm @Args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($Args -join ' ')`n  -> $($o -join "`n     ")" }
    $o
}
function VMState {
    param($vm)
    ((& $vbm showvminfo $vm --machinereadable 2>$null | Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim()
}

# --- .NET helper to write the IMAPI2 result stream to disk ---------------------
if (-not ('IsoHelper' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class IsoHelper {
    public static void Save(object comStream, string path) {
        IStream s = (IStream)comStream;
        using (FileStream fs = File.Create(path)) {
            byte[] buf = new byte[2048];
            IntPtr pRead = Marshal.AllocHGlobal(sizeof(int));
            try {
                while (true) {
                    s.Read(buf, buf.Length, pRead);
                    int n = Marshal.ReadInt32(pRead);
                    if (n <= 0) break;
                    fs.Write(buf, 0, n);
                }
            } finally { Marshal.FreeHGlobal(pRead); }
        }
    }
}
'@
}

function New-OemdrvIso {
    param([string]$KsContent, [string]$OutIso)
    $tmp = Join-Path $env:TEMP ("ks-" + [guid]::NewGuid().ToString('N') + ".cfg")
    # Kickstart must have UNIX line endings and no BOM.
    [System.IO.File]::WriteAllText($tmp, ($KsContent -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3          # ISO9660 + Joliet
    $fsi.VolumeName = 'OEMDRV'            # the magic label Anaconda looks for
    $st = New-Object -ComObject ADODB.Stream
    $st.Open(); $st.Type = 1; $st.LoadFromFile($tmp)
    $fsi.Root.AddFile('ks.cfg', $st)
    $res = $fsi.CreateResultImage()
    if (Test-Path $OutIso) { Remove-Item $OutIso -Force }
    [IsoHelper]::Save($res.ImageStream, $OutIso)
    $st.Close()
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

$nodes = @(
    @{ Name='rhcsa-node1'; Ks='ks-node1.cfg'; SshPort=2201 },
    @{ Name='rhcsa-node2'; Ks='ks-node2.cfg'; SshPort=2202 }
)

# ---------------------------------------------------------------- 1. SSH key
Head 'SSH key'
$keyDir = Join-Path $LabRoot '.ssh'
$keyFile = Join-Path $keyDir 'lab_key'
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
if (-not (Test-Path $keyFile)) {
    # PowerShell mangles quoting when passing an empty -N to a native exe: '""' arrives
    # as a literal two-character passphrase, which then breaks BatchMode auth. Generate
    # with a throwaway passphrase, then strip it - that round-trip is quoting-safe.
    & ssh-keygen -t ed25519 -f $keyFile -N 'tmp' -C 'rhcsa-lab' -q 2>&1 | Out-Null
    & ssh-keygen -p -P 'tmp' -N '' -f $keyFile 2>&1 | Out-Null
    Say 'generated new keypair'
} else { Say 'reusing existing keypair' }

# Fail loudly rather than hanging on a password prompt later.
& ssh-keygen -y -P '' -f $keyFile 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Key $keyFile is passphrase-protected; BatchMode ssh will fail. Delete it and re-run." }
$pubKey = (Get-Content "$keyFile.pub" -Raw).Trim()
if (-not $pubKey) { throw 'failed to read public key' }
Good "key ready ($($pubKey.Substring(0,32))...)"

if (-not $SkipInstall) {
    # ------------------------------------------------------- 2. build + attach
    Head 'Kickstart media'
    foreach ($n in $nodes) {
        $ksPath = Join-Path $LabRoot "kickstart\$($n.Ks)"
        if (-not (Test-Path $ksPath)) { throw "missing kickstart: $ksPath" }
        $content = (Get-Content $ksPath -Raw).Replace('@@SSHKEY@@', $pubKey)
        if ($content -match '@@SSHKEY@@') { throw "key substitution failed for $($n.Ks)" }

        $outIso = Join-Path $LabRoot "kickstart\oemdrv-$($n.Name).iso"
        New-OemdrvIso -KsContent $content -OutIso $outIso
        Say "$($n.Name): built $(Split-Path $outIso -Leaf) ($([math]::Round((Get-Item $outIso).Length/1KB))KB)"

        if ((VMState $n.Name) -eq 'running') { & $vbm controlvm $n.Name poweroff 2>&1 | Out-Null; Start-Sleep 2 }

        # Re-attach the install DVD every run so swapping ISOs (Rocky <-> RHEL) just works.
        VBox storageattach $n.Name --storagectl SATA --port 5 --device 0 --type dvddrive --medium $IsoPath | Out-Null
        VBox storageattach $n.Name --storagectl SATA --port 4 --device 0 --type dvddrive --medium $outIso | Out-Null
        VBox modifyvm $n.Name --boot1 dvd --boot2 disk | Out-Null

        # NAT port-forward for SSH (host-only isn't configured on node1 yet - that's T01)
        & $vbm modifyvm $n.Name --natpf1 delete ssh 2>&1 | Out-Null
        VBox modifyvm $n.Name --natpf1 "ssh,tcp,127.0.0.1,$($n.SshPort),,22" | Out-Null
        Say "$($n.Name): ssh forwarded on 127.0.0.1:$($n.SshPort)"
    }

    # ---------------------------------------------------------- 3. run install
    Head 'Unattended install (both nodes in parallel)'
    foreach ($n in $nodes) {
        VBox startvm $n.Name --type headless | Out-Null
        Say "$($n.Name): booting installer"
    }

    # The GRUB menu defaults to "Test this media & install", which spends ~10 min
    # checksumming a 14 GB ISO we already verified. Nudge the selection up one to
    # plain "Install", then confirm. Harmless if the menu has already timed out.
    Say 'waiting for GRUB menu...'
    Start-Sleep -Seconds 40
    foreach ($n in $nodes) {
        & $vbm controlvm $n.Name keyboardputscancode e0 48 e0 c8 2>&1 | Out-Null   # Up
        Start-Sleep -Milliseconds 400
        & $vbm controlvm $n.Name keyboardputscancode 1c 9c 2>&1 | Out-Null         # Enter
        Say "$($n.Name): selected 'Install' (skipping media check)"
    }
    Write-Host "  Installing. This takes 15-30 min - nothing to click." -ForegroundColor DarkGray

    $deadline = (Get-Date).AddMinutes($InstallTimeoutMin)
    $done = @{}
    while ((Get-Date) -lt $deadline -and $done.Count -lt $nodes.Count) {
        Start-Sleep -Seconds 20
        foreach ($n in $nodes) {
            if ($done.ContainsKey($n.Name)) { continue }
            $s = VMState $n.Name
            if ($s -eq 'poweroff' -or $s -eq 'aborted') {
                $done[$n.Name] = $s
                if ($s -eq 'aborted') { Warn "$($n.Name): ABORTED - check the VM log" }
                else { Good "$($n.Name): install finished" }
            }
        }
        $el = [int]((Get-Date) - $deadline.AddMinutes(-$InstallTimeoutMin)).TotalMinutes
        Write-Host "`r  ...$el min elapsed, $($done.Count)/$($nodes.Count) done   " -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ''
    if ($done.Count -lt $nodes.Count) {
        throw "Timed out after $InstallTimeoutMin min. Open the VM window to see where it stopped."
    }

    # ------------------------------------------------- 4. flip to boot-from-disk
    Head 'Post-install reconfiguration'
    foreach ($n in $nodes) {
        # Detach kickstart media; KEEP the install DVD attached - task T13 mounts it.
        VBox storageattach $n.Name --storagectl SATA --port 4 --device 0 --medium none | Out-Null
        VBox modifyvm $n.Name --boot1 disk --boot2 dvd | Out-Null
        Say "$($n.Name): boots from disk, install DVD still attached for T13"
    }
}

# ------------------------------------------------------------- 5. boot + wait
Head 'Booting installed systems'
foreach ($n in $nodes) {
    if ((VMState $n.Name) -ne 'running') { VBox startvm $n.Name --type headless | Out-Null }
    Say "$($n.Name): starting"
}

$sshOpts = @('-i', $keyFile, '-o','StrictHostKeyChecking=no', '-o','UserKnownHostsFile=NUL',
             '-o','ConnectTimeout=5', '-o','LogLevel=ERROR')
$deadline = (Get-Date).AddMinutes(6)
$up = @{}
while ((Get-Date) -lt $deadline -and $up.Count -lt $nodes.Count) {
    foreach ($n in $nodes) {
        if ($up.ContainsKey($n.Name)) { continue }
        $r = & ssh @sshOpts -p $n.SshPort "root@127.0.0.1" 'echo ok' 2>$null
        if ($r -match 'ok') { $up[$n.Name] = $true; Good "$($n.Name): SSH up on port $($n.SshPort)" }
    }
    if ($up.Count -lt $nodes.Count) { Start-Sleep -Seconds 10 }
}
if ($up.Count -lt $nodes.Count) { Warn "not all nodes answered SSH; continuing anyway" }

# ------------------------------------------------------ 6. push the task files
Head 'Copying tasks and grader to node1'
$files = @('TASKS.md','grade.sh','ANSWERS.md') | ForEach-Object { Join-Path $LabRoot $_ } | Where-Object { Test-Path $_ }
if ($files) {
    & scp @sshOpts -P 2201 @files "root@127.0.0.1:/root/" 2>&1 | Out-Null
    $ls = & ssh @sshOpts -p 2201 "root@127.0.0.1" 'ls -1 /root/*.md /root/*.sh 2>/dev/null'
    foreach ($f in $ls) { Say "node1:$f" }
    & ssh @sshOpts -p 2201 "root@127.0.0.1" 'chmod +x /root/grade.sh' 2>&1 | Out-Null
    Good 'files in place'
} else { Warn 'no task files found to copy' }

# ------------------------------------------------------------- 7. snapshot
Head 'Snapshots'
foreach ($n in $nodes) {
    if ((VMState $n.Name) -eq 'running') { & $vbm controlvm $n.Name acpipowerbutton 2>&1 | Out-Null }
}
Start-Sleep -Seconds 25
foreach ($n in $nodes) {
    $t = (Get-Date).AddSeconds(60)
    while ((VMState $n.Name) -eq 'running' -and (Get-Date) -lt $t) { Start-Sleep 5 }
    if ((VMState $n.Name) -eq 'running') { & $vbm controlvm $n.Name poweroff 2>&1 | Out-Null; Start-Sleep 3 }
    & $vbm snapshot $n.Name delete clean-install 2>&1 | Out-Null
    VBox snapshot $n.Name take clean-install --description 'fresh install, no tasks done' | Out-Null
    Good "$($n.Name): snapshot 'clean-install' taken"
}

Write-Host @"

=== LAB READY ===

  Start practising:
    & '$vbm' startvm rhcsa-node1 --type headless
    & '$vbm' startvm rhcsa-node2 --type headless

  Log in from this machine (no password needed):
    ssh -i "$keyFile" -p 2201 root@127.0.0.1      # node1 - do the tasks here
    ssh -i "$keyFile" -p 2202 root@127.0.0.1      # node2 - test from here

  Or use the VirtualBox console window. Root password: Rhcsa!2026

  On node1:
    cat /root/TASKS.md              the 15 tasks
    sudo bash /root/grade.sh -v     score yourself
    cat /root/ANSWERS.md            answer key (try first!)

  Roll back to a clean box any time:
    & '$vbm' snapshot rhcsa-node1 restore clean-install

"@ -ForegroundColor Cyan
