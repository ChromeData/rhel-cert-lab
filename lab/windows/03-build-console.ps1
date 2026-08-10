<#
.SYNOPSIS
    Builds rhcsa-console: the graphical exam console VM.

.DESCRIPTION
    Mirrors the real EX200 remote-exam layout - a graphical environment running Firefox
    (the exam paper, with countdown timer) plus terminals into the systems under test.
    node1 and node2 are the machines being graded; nothing on the console is graded.

    Creates the VM, installs Rocky 9 + GNOME unattended, deploys the exam paper, wires
    up desktop launchers, and snapshots.

.EXAMPLE
    .\03-build-console.ps1
    .\03-build-console.ps1 -Force      # tear down and rebuild
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$LabRoot    = $PSScriptRoot,
    [string]$IsoPath    = 'E:\RHCSA-Lab\iso\Rocky-9.8-x86_64-dvd.iso',
    [string]$BaseFolder = 'E:\RHCSA-Lab\VMs',
    [int]$MemoryMB      = 4096,
    [int]$Cpus          = 4,
    [int]$DiskGB        = 30,
    [int]$TimeoutMin    = 60,
    [switch]$Force,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbm)) { throw "VBoxManage not found" }

$VM   = 'rhcsa-console'
$PORT = 2200

function Say  { param($m) Write-Host "  -> $m" -ForegroundColor DarkGray }
function Head { param($m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Good { param($m) Write-Host "  OK: $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  !!  $m" -ForegroundColor Yellow }
function VBox { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    $o = & $vbm @Args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "VBoxManage $($Args -join ' ')`n  -> $($o -join "`n     ")" }
    $o }
function VMState { param($vm)
    ((& $vbm showvminfo $vm --machinereadable 2>$null | Select-String '^VMState=') -replace 'VMState=','' -replace '"','').Trim() }

if (-not ('IsoHelper' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Runtime.InteropServices; using System.Runtime.InteropServices.ComTypes;
public static class IsoHelper {
  public static void Save(object comStream, string path) {
    IStream s = (IStream)comStream;
    using (FileStream fs = File.Create(path)) {
      byte[] buf = new byte[2048]; IntPtr pRead = Marshal.AllocHGlobal(sizeof(int));
      try { while (true) { s.Read(buf, buf.Length, pRead); int n = Marshal.ReadInt32(pRead);
              if (n <= 0) break; fs.Write(buf, 0, n); } }
      finally { Marshal.FreeHGlobal(pRead); } } } }
'@
}

function New-OemdrvIso {
    param([string]$KsContent, [string]$OutIso)
    $tmp = Join-Path $env:TEMP ("ks-" + [guid]::NewGuid().ToString('N') + ".cfg")
    [System.IO.File]::WriteAllText($tmp, ($KsContent -replace "`r`n","`n"), (New-Object System.Text.UTF8Encoding($false)))
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3; $fsi.VolumeName = 'OEMDRV'
    $st = New-Object -ComObject ADODB.Stream; $st.Open(); $st.Type = 1; $st.LoadFromFile($tmp)
    $fsi.Root.AddFile('ks.cfg', $st)
    $res = $fsi.CreateResultImage()
    if (Test-Path $OutIso) { Remove-Item $OutIso -Force }
    [IsoHelper]::Save($res.ImageStream, $OutIso)
    $st.Close(); Remove-Item $tmp -Force -EA SilentlyContinue
}

# ---------------------------------------------------------------- ssh key
Head 'SSH key'
$keyFile = Join-Path $LabRoot '.ssh\lab_key'
if (-not (Test-Path $keyFile)) { throw "Missing $keyFile - run 02-install-os.ps1 first." }
& ssh-keygen -y -P '' -f $keyFile 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Key is passphrase-protected; BatchMode ssh will fail." }
$pubKey = (Get-Content "$keyFile.pub" -Raw).Trim()
Good 'key ready'

$sshOpts = @('-i',$keyFile,'-o','BatchMode=yes','-o','StrictHostKeyChecking=no',
             '-o','UserKnownHostsFile=NUL','-o','ConnectTimeout=8','-o','LogLevel=ERROR')

if (-not $SkipInstall) {
    # ------------------------------------------------------------ create VM
    Head "Creating $VM"
    if ((& $vbm list vms) -match [regex]::Escape("`"$VM`"")) {
        if (-not $Force) { Write-Host "  SKIP: $VM exists. Use -Force to rebuild." -ForegroundColor Yellow; $SkipInstall = $true }
        else {
            & $vbm controlvm $VM poweroff 2>&1 | Out-Null; Start-Sleep 2
            VBox unregistervm $VM --delete | Out-Null
            $d = Join-Path $BaseFolder $VM
            if (Test-Path $d) { Remove-Item $d -Recurse -Force -EA SilentlyContinue }
            Say 'removed existing VM'
        }
    }
}

if (-not $SkipInstall) {
    $vmDir = Join-Path $BaseFolder $VM
    VBox createvm --name $VM --ostype RedHat_64 --register --basefolder $BaseFolder | Out-Null
    VBox modifyvm $VM --memory $MemoryMB --cpus $Cpus --vram 128 --firmware efi `
        --ioapic on --rtcuseutc on --graphicscontroller vmsvga --accelerate3d off | Out-Null
    VBox modifyvm $VM --nic1 nat --nictype1 virtio | Out-Null
    $ho = ((& $vbm list hostonlyifs | Select-String '^Name:\s+(.+)$') | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } | Select-Object -First 1)
    VBox modifyvm $VM --nic2 hostonly --nictype2 virtio --hostonlyadapter2 $ho | Out-Null
    & $vbm modifyvm $VM --natpf1 delete ssh 2>&1 | Out-Null
    VBox modifyvm $VM --natpf1 "ssh,tcp,127.0.0.1,$PORT,,22" | Out-Null
    Say "4 GB / $Cpus vCPU / ${DiskGB} GB, ssh on 127.0.0.1:$PORT"

    $vdi = Join-Path $vmDir "$VM-os.vdi"
    VBox createmedium disk --filename $vdi --size ($DiskGB*1024) --format VDI | Out-Null
    VBox storagectl $VM --name SATA --add sata --controller IntelAhci --portcount 6 --bootable on | Out-Null
    VBox storageattach $VM --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi | Out-Null
    VBox storageattach $VM --storagectl SATA --port 5 --device 0 --type dvddrive --medium $IsoPath | Out-Null

    $ks = (Get-Content (Join-Path $LabRoot 'kickstart\ks-console.cfg') -Raw).Replace('@@SSHKEY@@',$pubKey)
    if ($ks -match '@@SSHKEY@@') { throw 'key substitution failed' }
    $oem = Join-Path $LabRoot 'kickstart\oemdrv-console.iso'
    New-OemdrvIso -KsContent $ks -OutIso $oem
    VBox storageattach $VM --storagectl SATA --port 4 --device 0 --type dvddrive --medium $oem | Out-Null
    VBox modifyvm $VM --boot1 dvd --boot2 disk | Out-Null
    Good 'VM created, kickstart attached'

    # ---------------------------------------------------------- install
    Head 'Installing Rocky 9 + GNOME (unattended)'
    VBox startvm $VM --type headless | Out-Null
    Start-Sleep -Seconds 40
    & $vbm controlvm $VM keyboardputscancode e0 48 e0 c8 2>&1 | Out-Null
    Start-Sleep -Milliseconds 400
    & $vbm controlvm $VM keyboardputscancode 1c 9c 2>&1 | Out-Null
    Say "selected 'Install'; a desktop install takes 20-35 min"

    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 30
        $s = VMState $VM
        if ($s -eq 'poweroff' -or $s -eq 'aborted') { break }
        $el = [int]((Get-Date) - $deadline.AddMinutes(-$TimeoutMin)).TotalMinutes
        Write-Host "`r  ...$el min elapsed   " -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ''
    if ((VMState $VM) -eq 'running') { throw "Install timed out after $TimeoutMin min." }
    Good 'install finished'

    VBox storageattach $VM --storagectl SATA --port 4 --device 0 --medium none | Out-Null
    VBox modifyvm $VM --boot1 disk --boot2 dvd | Out-Null
}

# ------------------------------------------------------------- boot + wait
Head 'Booting console'
if ((VMState $VM) -ne 'running') { VBox startvm $VM --type gui | Out-Null }
Say 'started with a visible window (this is your exam screen)'

$deadline = (Get-Date).AddMinutes(8); $up = $false
while ((Get-Date) -lt $deadline -and -not $up) {
    if ((& ssh @sshOpts -p $PORT root@127.0.0.1 'echo ok' 2>$null) -match 'ok') { $up = $true }
    else { Start-Sleep -Seconds 10 }
}
if (-not $up) { Warn 'console did not answer SSH; deploying may fail' } else { Good 'console is up' }

# -------------------------------------------------------- deploy exam paper
Head 'Deploying exam paper and desktop launchers'
$exam = Join-Path $LabRoot 'exam\exam.html'
if (-not (Test-Path $exam)) { throw "Missing $exam" }
& scp @sshOpts -P $PORT $exam "root@127.0.0.1:/home/exam/exam.html" 2>&1 | Out-Null
Say 'exam.html copied'

$setup = @'
set -e
chown exam:exam /home/exam/exam.html
chmod 644 /home/exam/exam.html

# Firefox opens the exam paper automatically at login, like the exam environment.
mkdir -p /home/exam/.config/autostart
cat > /home/exam/.config/autostart/exam-paper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=RHCSA Exam Paper
Exec=firefox --new-window file:///home/exam/exam.html
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=6
EOF

# Desktop shortcuts: exam paper, and a terminal on each system under test.
mkdir -p /home/exam/Desktop
cat > /home/exam/Desktop/exam-paper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Exam Paper
Comment=Tasks and countdown timer
Exec=firefox --new-window file:///home/exam/exam.html
Icon=text-html
Terminal=false
EOF
cat > /home/exam/Desktop/node1.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminal - node1
Comment=Root shell on the system under test
Exec=gnome-terminal --title="node1" -- ssh node1
Icon=utilities-terminal
Terminal=false
EOF
cat > /home/exam/Desktop/node2.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminal - node2
Comment=Root shell on the second system
Exec=gnome-terminal --title="node2" -- ssh node2
Icon=utilities-terminal
Terminal=false
EOF
chmod +x /home/exam/Desktop/*.desktop
chown -R exam:exam /home/exam/Desktop /home/exam/.config
for f in /home/exam/Desktop/*.desktop; do
  sudo -u exam gio set "$f" metadata::trusted true 2>/dev/null || true
done

# Give the exam user the lab key so its terminals reach node1/node2 without a password.
install -d -m 700 -o exam -g exam /home/exam/.ssh
echo "setup complete"
'@
& ssh @sshOpts -p $PORT root@127.0.0.1 $setup 2>&1 | ForEach-Object { Say $_ }

& scp @sshOpts -P $PORT $keyFile "root@127.0.0.1:/home/exam/.ssh/id_ed25519" 2>&1 | Out-Null
& ssh @sshOpts -p $PORT root@127.0.0.1 'chown exam:exam /home/exam/.ssh/id_ed25519; chmod 600 /home/exam/.ssh/id_ed25519; sed -i "s|^Host node|IdentityFile /home/exam/.ssh/id_ed25519\nHost node|" /dev/null 2>/dev/null; grep -q IdentityFile /home/exam/.ssh/config || sed -i "/^Host node1/a\\    IdentityFile /home/exam/.ssh/id_ed25519" /home/exam/.ssh/config; grep -c IdentityFile /home/exam/.ssh/config' 2>&1 | ForEach-Object { Say "IdentityFile entries: $_" }
Good 'exam paper and launchers deployed'

Write-Host @"

=== EXAM CONSOLE READY ===

  A VirtualBox window is open showing the console desktop. It logs in
  automatically and Firefox opens the exam paper with the countdown timer.

  On the desktop:
    Exam Paper        the tasks + timer
    Terminal - node1  root shell on the system you configure
    Terminal - node2  root shell on the second system

  Console login (if it ever asks):  exam / Rhcsa!2026

  Systems under test:
    node1  192.168.56.101
    node2  192.168.56.102

  Reset everything to a clean slate before a fresh attempt:
    & '$vbm' snapshot rhcsa-node1 restore clean-install
    & '$vbm' snapshot rhcsa-node2 restore clean-install

"@ -ForegroundColor Cyan
