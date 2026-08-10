<#
.SYNOPSIS
    Builds a two-node RHCSA (EX200) practice lab in VirtualBox.

.DESCRIPTION
    Creates rhcsa-node1 and rhcsa-node2:
      - NIC1 = NAT          (internet, for dnf)
      - NIC2 = host-only    (192.168.56.0/24, node-to-node + firewall testing)
      - node1 = OS disk + TWO blank disks (LVM / partitioning / swap practice)
      - node2 = OS disk + ONE blank disk

    VM disks land on E: because C: only has ~3.5 GB free.

.EXAMPLE
    .\01-create-vms.ps1 -IsoPath "E:\RHCSA-Lab\iso\rhel-10.0-x86_64-dvd.iso"

.EXAMPLE
    .\01-create-vms.ps1 -IsoPath "E:\...\Rocky-10-dvd.iso" -Force
    Destroys and rebuilds both VMs from scratch.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$BaseFolder  = 'E:\RHCSA-Lab\VMs',
    [int]$MemoryMB       = 4096,
    [int]$Cpus           = 4,
    [int]$OsDiskGB       = 20,
    [int]$ExtraDiskGB    = 10,

    # RHEL 10 boots UEFI reliably; flip to 'bios' only if the installer misbehaves.
    [ValidateSet('efi', 'bios')]
    [string]$Firmware    = 'efi',

    # Destroy existing VMs of the same name first.
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# --- locate VBoxManage -------------------------------------------------------
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $vbm)) {
    $cmd = Get-Command VBoxManage -ErrorAction SilentlyContinue
    if ($cmd) { $vbm = $cmd.Source } else { throw "VBoxManage.exe not found. Is VirtualBox installed?" }
}

function Invoke-VBox {
    <# Runs VBoxManage and throws on non-zero exit, surfacing stderr. #>
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $out = & $vbm @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage $($Args -join ' ')`n  -> $($out -join "`n     ")"
    }
    return $out
}

function Write-Step { param([string]$Msg) Write-Host "  -> $Msg" -ForegroundColor DarkGray }

# --- preflight ---------------------------------------------------------------
Write-Host "`n=== Preflight ===" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $IsoPath)) {
    throw "ISO not found: $IsoPath`nDownload one first - see README.md, section 1."
}
$isoGB = [math]::Round((Get-Item -LiteralPath $IsoPath).Length / 1GB, 2)
Write-Step "ISO: $IsoPath ($isoGB GB)"

# Host-only adapter: reuse the existing one rather than creating a duplicate.
$hostOnly = (& $vbm list hostonlyifs |
             Select-String -Pattern '^Name:\s+(.+)$' |
             ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } |
             Select-Object -First 1)
if (-not $hostOnly) {
    Write-Step "No host-only adapter found - creating one"
    $created = Invoke-VBox hostonlyif create
    $hostOnly = ([regex]::Match(($created -join ' '), "Interface '([^']+)'")).Groups[1].Value
    Invoke-VBox hostonlyif ipconfig $hostOnly --ip 192.168.56.1 --netmask 255.255.255.0
}
Write-Step "Host-only adapter: $hostOnly"

# Disk space: 2 VMs x (OS + extras) plus headroom.
$needGB  = ($OsDiskGB * 2) + ($ExtraDiskGB * 3) + 5
$driveLtr = (Split-Path -Qualifier $BaseFolder).TrimEnd(':')
$freeGB  = [math]::Round((Get-PSDrive -Name $driveLtr).Free / 1GB, 1)
if ($freeGB -lt $needGB) {
    throw "Need ~$needGB GB on ${driveLtr}: but only $freeGB GB free."
}
Write-Step "Space on ${driveLtr}: $freeGB GB free (need ~$needGB GB)"

New-Item -ItemType Directory -Force -Path $BaseFolder | Out-Null

# --- node definitions --------------------------------------------------------
$nodes = @(
    @{ Name = 'rhcsa-node1'; Extras = 2 },   # two spare disks: LVM + swap practice
    @{ Name = 'rhcsa-node2'; Extras = 1 }
)

foreach ($node in $nodes) {
    $vm     = $node.Name
    $vmDir  = Join-Path $BaseFolder $vm

    Write-Host "`n=== $vm ===" -ForegroundColor Cyan

    # -- existing VM handling --
    $exists = (& $vbm list vms) -match [regex]::Escape("`"$vm`"")
    if ($exists) {
        if (-not $Force) {
            Write-Host "  SKIP: '$vm' already exists. Re-run with -Force to rebuild it." -ForegroundColor Yellow
            continue
        }
        Write-Step "Removing existing VM (-Force)"
        & $vbm controlvm $vm poweroff 2>&1 | Out-Null   # may already be off; ignore
        Start-Sleep -Milliseconds 800
        Invoke-VBox unregistervm $vm --delete
        if (Test-Path -LiteralPath $vmDir) {
            Remove-Item -LiteralPath $vmDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # -- create + configure --
    Write-Step "Creating VM"
    Invoke-VBox createvm --name $vm --ostype RedHat_64 --register --basefolder $BaseFolder

    Write-Step "CPU/RAM/firmware: ${Cpus} vCPU, ${MemoryMB} MB, $Firmware"
    Invoke-VBox modifyvm $vm `
        --memory $MemoryMB --cpus $Cpus --vram 32 `
        --firmware $Firmware --ioapic on --rtcuseutc on `
        --graphicscontroller vmsvga

    Write-Step "NIC1 = NAT, NIC2 = host-only"
    Invoke-VBox modifyvm $vm --nic1 nat      --nictype1 virtio
    Invoke-VBox modifyvm $vm --nic2 hostonly --nictype2 virtio --hostonlyadapter2 $hostOnly

    # -- storage --
    Write-Step "Adding SATA controller"
    Invoke-VBox storagectl $vm --name SATA --add sata --controller IntelAhci --portcount 6 --bootable on

    $osVdi = Join-Path $vmDir "$vm-os.vdi"
    Write-Step "OS disk: ${OsDiskGB} GB"
    Invoke-VBox createmedium disk --filename $osVdi --size ($OsDiskGB * 1024) --format VDI
    Invoke-VBox storageattach $vm --storagectl SATA --port 0 --device 0 --type hdd --medium $osVdi

    for ($i = 1; $i -le $node.Extras; $i++) {
        $extraVdi = Join-Path $vmDir "$vm-extra$i.vdi"
        Write-Step "Spare disk ${i}: ${ExtraDiskGB} GB (blank, for storage tasks)"
        Invoke-VBox createmedium disk --filename $extraVdi --size ($ExtraDiskGB * 1024) --format VDI
        Invoke-VBox storageattach $vm --storagectl SATA --port $i --device 0 --type hdd --medium $extraVdi
    }

    Write-Step "Attaching install ISO"
    Invoke-VBox storageattach $vm --storagectl SATA --port 5 --device 0 --type dvddrive --medium $IsoPath
    Invoke-VBox modifyvm $vm --boot1 dvd --boot2 disk --boot3 none --boot4 none

    Write-Host "  OK: $vm ready" -ForegroundColor Green
}

# --- summary -----------------------------------------------------------------
Write-Host @"

=== Lab built ===

  rhcsa-node1   192.168.56.101   (set this during install)
  rhcsa-node2   192.168.56.102
  gateway/DNS   192.168.56.1     (host-only network)

Start them:
  & '$vbm' startvm rhcsa-node1
  & '$vbm' startvm rhcsa-node2

Next: follow README.md section 2 (install) then section 3 (snapshot).
Do NOT skip the snapshot step - you will want to roll back constantly.
"@ -ForegroundColor Cyan
