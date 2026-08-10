#!/usr/bin/env bash
#
# RHCSA practice grader - Set 2
#
#   sudo bash grade2.sh          grade everything
#   sudo bash grade2.sh -t 19    grade only task 19
#   sudo bash grade2.sh -v       show why each check failed
#
# Node-aware: T21 and T22 are graded only when run on node2; everything else on node1.

set -uo pipefail

VERBOSE=0; ONLY=""
while getopts "t:vh" opt; do
  case $opt in
    t) ONLY="$OPTARG" ;; v) VERBOSE=1 ;;
    h) sed -n '2,10p' "$0"; exit 0 ;; *) exit 2 ;;
  esac
done
[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

if [[ -t 1 ]]; then R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else R=""; G=""; Y=""; B=""; D=""; N=""; fi

PASS=0; FAIL=0; SKIP=0; TOTAL=0; FAILED_TASKS=()
CUR_ID=""; CUR_NAME=""; CUR_ERRS=()

task()  { CUR_ID="$1"; CUR_NAME="$2"; CUR_ERRS=(); }
fails() { CUR_ERRS+=("$1"); }
checkv(){ local d="$1" w="$2" g="$3"; [[ "$w" == "$g" ]] || CUR_ERRS+=("$d (want '$w', got '${g:-<empty>}')"); }
report(){
  TOTAL=$((TOTAL+1))
  if [[ ${#CUR_ERRS[@]} -eq 0 ]]; then PASS=$((PASS+1)); printf "  %sPASS%s  T%-3s %s\n" "$G" "$N" "$CUR_ID" "$CUR_NAME"
  else FAIL=$((FAIL+1)); FAILED_TASKS+=("T$CUR_ID"); printf "  %sFAIL%s  T%-3s %s\n" "$R" "$N" "$CUR_ID" "$CUR_NAME"
    [[ $VERBOSE -eq 1 ]] && for e in "${CUR_ERRS[@]}"; do printf "        %s- %s%s\n" "$D" "$e" "$N"; done
  fi
}
skipt(){ SKIP=$((SKIP+1)); printf "  %sSKIP%s  T%-3s %s %s(%s)%s\n" "$Y" "$N" "$1" "$2" "$D" "$3" "$N"; }
want(){ [[ -z "$ONLY" || "$ONLY" == "$1" || "$ONLY" == "$((10#$1))" ]]; }
unit_ok(){ systemctl is-enabled "$1" >/dev/null 2>&1 && systemctl is-active "$1" >/dev/null 2>&1; }

# Which node are we on?
IS_NODE2=0
ip -4 addr show 2>/dev/null | grep -q '192\.168\.56\.102' && IS_NODE2=1
[[ "$(hostname -s)" == "node2" ]] && IS_NODE2=1

echo
echo "${B}=== RHCSA Practice Grader - Set 2 ===${N}"
echo "${D}host: $(hostname) | role: $( [[ $IS_NODE2 -eq 1 ]] && echo node2 || echo node1 )${N}"
echo

# ------------------------------------------------------- T16 root pw recovery
if want 16; then
  task 16 "Root password recovered and set to Rhcsa!2026"
  h=$(getent shadow root 2>/dev/null | cut -d: -f2)
  case "$h" in
    ""|"!"*|"*"|"!!") fails "root has no usable password" ;;
    \$6\$*) s=$(cut -d'$' -f3 <<<"$h")
            [[ "$(openssl passwd -6 -salt "$s" 'Rhcsa!2026' 2>/dev/null)" == "$h" ]] \
              || fails "root password is not 'Rhcsa!2026'" ;;
    *) [[ $VERBOSE -eq 1 ]] && echo "        ${D}note: $(cut -d'$' -f2 <<<"$h") hash not verifiable here${N}" ;;
  esac
  # An SELinux relabel is the classic post-rd.break gotcha; warn if contexts look wrong.
  [[ -e /.autorelabel ]] && fails "/.autorelabel still present - system needs a relabel reboot"
  report
fi

# ------------------------------------------------------------- T17 script #1
if want 17; then
  task 17 "/usr/local/bin/reportuser"
  S=/usr/local/bin/reportuser
  if [[ ! -x "$S" ]]; then fails "$S missing or not executable"
  else
    out=$("$S" 2>&1); rc=$?
    [[ $rc -eq 1 ]] || fails "no-arg exit status is $rc (want 1)"
    grep -qi 'usage' <<<"$out" || fails "no-arg output lacks a Usage message"

    if id root >/dev/null 2>&1; then
      out=$("$S" root 2>&1); rc=$?
      [[ $rc -eq 0 ]] || fails "valid-user exit status is $rc (want 0)"
      grep -q '\b0\b' <<<"$out" || fails "valid-user output does not show UID"
      grep -Eqi 'root|/bin/(ba)?sh' <<<"$out" || fails "valid-user output does not show shell/group"
    fi

    out=$("$S" nosuchuser_zz 2>&1); rc=$?
    [[ $rc -eq 2 ]] || fails "bad-user exit status is $rc (want 2)"
    grep -qi 'no such user' <<<"$out" || fails "bad-user message missing 'no such user'"
    [[ "$(stat -c '%a' "$S")" =~ [157][157][157] ]] || fails "not executable by all (mode $(stat -c '%a' "$S"))"
  fi
  report
fi

# ------------------------------------------------------------- T18 script #2
if want 18; then
  task 18 "/usr/local/bin/sizes"
  S=/usr/local/bin/sizes
  if [[ ! -x "$S" ]]; then fails "$S missing or not executable"
  else
    tmp=$(mktemp -d)
    head -c 300  /dev/zero > "$tmp/small.bin"
    head -c 5000 /dev/zero > "$tmp/big.bin"
    head -c 1200 /dev/zero > "$tmp/mid.bin"
    mkdir "$tmp/adir"
    out=$("$S" "$tmp" 2>/dev/null)
    first=$(head -1 <<<"$out" | awk '{print $1}')
    [[ "$(basename "$first")" == "big.bin" ]] || fails "largest file not listed first (got '${first:-nothing}')"
    grep -q '5000' <<<"$out" || fails "byte sizes not shown"
    [[ $(grep -c . <<<"$out") -eq 3 ]] || fails "expected 3 lines (regular files only), got $(grep -c . <<<"$out")"
    grep -q 'adir' <<<"$out" && fails "directories should be excluded"
    "$S" /definitely/not/a/dir >/dev/null 2>&1; rc=$?
    [[ $rc -eq 1 ]] || fails "non-directory arg exit status is $rc (want 1)"
    rm -rf "$tmp"
  fi
  report
fi

# ------------------------------------------------------------------ T19 ACLs
if want 19; then
  task 19 "ACLs on /srv/shared/report.txt"
  F=/srv/shared/report.txt
  if [[ ! -f "$F" ]]; then fails "$F does not exist"
  else
    acl=$(getfacl -pE "$F" 2>/dev/null)
    checkv "group owner" "admin" "$(stat -c '%G' "$F")"
    grep -Eq '^user:harry:rw-?' <<<"$acl" || fails "harry lacks an rw ACL entry"
    grep -Eq '^user:tom:---'    <<<"$acl" || fails "tom does not have an explicit no-access ACL entry"
    m=$(grep -E '^mask::' <<<"$acl" | cut -d: -f3)
    [[ "$m" == *r* && "$m" == *w* ]] || fails "ACL mask ($m) is squashing harry's write permission"
  fi
  report
fi

# ------------------------------------------------------------ T20 NFS export
if want 20; then
  if [[ $IS_NODE2 -eq 1 ]]; then skipt 20 "NFS export" "node1 task"
  else
    task 20 "NFS export of /srv/nfsshare to 192.168.56.0/24"
    [[ -d /srv/nfsshare ]] || fails "/srv/nfsshare does not exist"
    unit_ok nfs-server || fails "nfs-server is not enabled+active"
    ex=$(exportfs -s 2>/dev/null)
    grep -q '/srv/nfsshare' <<<"$ex" || fails "/srv/nfsshare is not exported"
    grep -q '192.168.56.0/24' <<<"$ex" || fails "export is not restricted to 192.168.56.0/24"
    grep -q 'rw' <<<"$ex" || fails "export is not read-write"
    grep -Eq '/srv/nfsshare' /etc/exports /etc/exports.d/* 2>/dev/null \
      || fails "export not in /etc/exports - will vanish on reboot"
    if systemctl is-active firewalld >/dev/null 2>&1; then
      firewall-cmd --permanent --list-all 2>/dev/null | grep -q 'nfs' \
        || fails "nfs not open in permanent firewall config"
    fi
    report
  fi
fi

# ------------------------------------------------------------- T21 NFS mount
if want 21; then
  if [[ $IS_NODE2 -eq 0 ]]; then skipt 21 "NFS mount at /mnt/remote" "node2 task"
  else
    task 21 "Persistent NFS mount at /mnt/remote"
    if ! findmnt -n /mnt/remote >/dev/null 2>&1; then fails "/mnt/remote is not mounted"
    else
      t=$(findmnt -n -o FSTYPE /mnt/remote); [[ "$t" == nfs* ]] || fails "/mnt/remote fstype is $t (want nfs)"
      findmnt -n -o SOURCE /mnt/remote | grep -q '192.168.56.101' || fails "not mounted from node1"
    fi
    grep -Eq '^[^#]*[[:space:]]/mnt/remote[[:space:]]' /etc/fstab 2>/dev/null \
      || fails "/mnt/remote not in /etc/fstab"
    report
  fi
fi

# ---------------------------------------------------------------- T22 autofs
if want 22; then
  if [[ $IS_NODE2 -eq 0 ]]; then skipt 22 "autofs /net/shared" "node2 task"
  else
    task 22 "autofs mounts /net/shared on demand"
    unit_ok autofs || fails "autofs is not enabled+active"
    grep -rhq '/net' /etc/auto.master /etc/auto.master.d/* 2>/dev/null \
      || fails "no /net entry in auto.master"
    ls /net/shared >/dev/null 2>&1
    sleep 1
    findmnt -n /net/shared >/dev/null 2>&1 || fails "/net/shared did not auto-mount on access"
    report
  fi
fi

# ----------------------------------------------------------- T23 log analysis
if want 23; then
  task 23 "Failed SSH logins captured + persistent journal"
  F=/root/failed-logins.txt
  [[ -f "$F" ]] || fails "$F does not exist"
  if [[ -f "$F" && ! -s "$F" ]]; then fails "$F is empty - generate a failed login first"; fi
  if [[ -s "$F" ]]; then
    grep -Eqi 'fail|invalid|authentication' "$F" || fails "$F contents don't look like failed-auth lines"
  fi
  [[ -d /var/log/journal ]] || fails "/var/log/journal missing - journal is not persistent"
  grep -Eq '^[[:space:]]*Storage[[:space:]]*=[[:space:]]*(persistent|auto)' /etc/systemd/journald.conf /etc/systemd/journald.conf.d/* 2>/dev/null \
    || fails "journald Storage= not set to persistent"
  report
fi

# ------------------------------------------------------------------ T24 time
if want 24; then
  task 24 "Time sync from 192.168.56.1, timezone America/New_York"
  checkv "timezone" "America/New_York" "$(timedatectl show -p Timezone --value 2>/dev/null)"
  checkv "NTP enabled" "yes" "$(timedatectl show -p NTP --value 2>/dev/null | sed 's/true/yes/;s/false/no/')"
  unit_ok chronyd || fails "chronyd not enabled+active"
  grep -rhq '192\.168\.56\.1' /etc/chrony.conf /etc/chrony.d/* 2>/dev/null \
    || fails "192.168.56.1 not configured as a time source"
  report
fi

# ----------------------------------------------------------------- T25 tuned
if want 25; then
  task 25 "tuned profile = virtual-guest"
  if ! command -v tuned-adm >/dev/null 2>&1; then fails "tuned not installed"
  else
    unit_ok tuned || fails "tuned not enabled+active"
    checkv "active profile" "virtual-guest" "$(tuned-adm active 2>/dev/null | sed 's/.*: //')"
  fi
  report
fi

# ------------------------------------------------------------- T26 container
if want 26; then
  task 26 "Rootless podman container 'webtest' starts at boot as harry"
  if ! command -v podman >/dev/null 2>&1; then fails "podman not installed"
  elif ! id harry >/dev/null 2>&1; then fails "user harry does not exist"
  else
    loginctl show-user harry 2>/dev/null | grep -q 'Linger=yes' \
      || fails "lingering not enabled for harry (loginctl enable-linger harry) - won't start at boot"
    runuser -l harry -c 'podman images' 2>/dev/null | grep -q 'ubi' \
      || fails "no ubi image in harry's rootless podman store"
    runuser -l harry -c 'podman ps --format "{{.Names}}"' 2>/dev/null | grep -qx 'webtest' \
      || fails "container 'webtest' is not running as harry"
    u=$(runuser -l harry -c 'systemctl --user list-unit-files --no-legend 2>/dev/null' | grep -Ei 'webtest|container-webtest')
    [[ -n "$u" ]] || fails "no systemd --user unit for the container"
    grep -q 'enabled' <<<"$u" || fails "container systemd user unit is not enabled"
  fi
  report
fi

# ---------------------------------------------------------------- T27 LV grow
if want 27; then
  task 27 "lvdata grown to 1 GiB online, filesystem included"
  if ! lvs vgdata/lvdata >/dev/null 2>&1; then fails "vgdata/lvdata does not exist"
  else
    sz=$(lvs --noheadings -o lv_size --units m vgdata/lvdata 2>/dev/null | tr -d ' m')
    awk -v s="${sz%%.*}" 'BEGIN{exit !(s>=1024 && s<=1040)}' || fails "lvdata is ${sz}M (want ~1024M)"
    if findmnt -n /data >/dev/null 2>&1; then
      avail=$(df -BM --output=size /data 2>/dev/null | tail -1 | tr -d ' M')
      [[ -n "$avail" && "$avail" -ge 900 ]] || fails "filesystem on /data is only ${avail}M - you grew the LV but not the fs"
    else
      fails "/data is not mounted"
    fi
  fi
  report
fi

# --------------------------------------------------------------- T28 second LV
if want 28; then
  task 28 "lvlogs 256M ext4 at /var/log/archive with noexec"
  if ! lvs vgdata/lvlogs >/dev/null 2>&1; then fails "vgdata/lvlogs does not exist"
  else
    sz=$(lvs --noheadings -o lv_size --units m vgdata/lvlogs 2>/dev/null | tr -d ' m')
    awk -v s="${sz%%.*}" 'BEGIN{exit !(s>=256 && s<=264)}' || fails "lvlogs is ${sz}M (want 256M)"
  fi
  if ! findmnt -n /var/log/archive >/dev/null 2>&1; then fails "/var/log/archive not mounted"
  else
    checkv "filesystem" "ext4" "$(findmnt -n -o FSTYPE /var/log/archive)"
    findmnt -n -o OPTIONS /var/log/archive | grep -q 'noexec' || fails "noexec option not active"
  fi
  grep -Eq '^[^#]*[[:space:]]/var/log/archive[[:space:]]' /etc/fstab 2>/dev/null \
    || fails "/var/log/archive not in /etc/fstab"
  grep -E '^[^#]*[[:space:]]/var/log/archive[[:space:]]' /etc/fstab 2>/dev/null | grep -q noexec \
    || fails "noexec not recorded in /etc/fstab - lost on reboot"
  report
fi

# ------------------------------------------------------------ T29 pw aging
if want 29; then
  task 29 "Password aging on natasha"
  if ! id natasha >/dev/null 2>&1; then fails "user natasha does not exist"
  else
    c=$(chage -l natasha 2>/dev/null)
    grep -Eq 'Maximum number of days between password change[[:space:]]*:[[:space:]]*60' <<<"$c" \
      || fails "max age is not 60 days"
    grep -Eq 'Number of days of warning before password expires[[:space:]]*:[[:space:]]*10' <<<"$c" \
      || fails "warning period is not 10 days"
    grep -Eq 'Password inactive[[:space:]]*:' <<<"$c" && \
      { [[ "$(getent shadow natasha | cut -d: -f7)" == "7" ]] || fails "inactive period is not 7 days"; }
    [[ "$(getent shadow natasha | cut -d: -f3)" == "0" ]] \
      || fails "password change not forced at next login (chage -d 0 natasha)"
  fi
  report
fi

# ------------------------------------------------------------------ T30 sudo
if want 30; then
  task 30 "admin group: passwordless systemctl + journalctl only"
  rules=$(grep -rhE '^[^#]*%admin' /etc/sudoers /etc/sudoers.d/* 2>/dev/null)
  if [[ -z "$rules" ]]; then fails "no sudoers rule for %admin"
  else
    grep -q 'NOPASSWD' <<<"$rules" || fails "rule does not include NOPASSWD"
    grep -q '/usr/bin/systemctl'  <<<"$rules" || fails "systemctl not permitted"
    grep -q '/usr/bin/journalctl' <<<"$rules" || fails "journalctl not permitted"
    grep -Eq '%admin[[:space:]]+ALL=\(ALL\)[[:space:]]*(NOPASSWD:)?[[:space:]]*ALL[[:space:]]*$' <<<"$rules" \
      && fails "rule grants ALL commands - must be limited to those two"
  fi
  visudo -c >/dev/null 2>&1 || fails "sudoers syntax is INVALID (visudo -c fails)"
  if id harry >/dev/null 2>&1; then
    sudo -l -U harry 2>/dev/null | grep -q 'systemctl' || fails "harry cannot actually run systemctl via sudo"
  fi
  report
fi

# ---------------------------------------------------------------------- score
echo
PCT=0; [[ $TOTAL -gt 0 ]] && PCT=$(( PASS * 100 / TOTAL ))
if   [[ $PCT -ge 70 ]]; then COL="$G"; elif [[ $PCT -ge 50 ]]; then COL="$Y"; else COL="$R"; fi
echo "${B}────────────────────────────────────────${N}"
printf "  Score: %s%d/%d  (%d%%)%s   %s\n" "$COL" "$PASS" "$TOTAL" "$PCT" "$N" \
       "$( [[ $PCT -ge 70 ]] && echo 'passing mark' || echo 'below 70% pass mark' )"
[[ $SKIP -gt 0 ]] && echo "  ${D}$SKIP task(s) skipped - they belong to the other node${N}"
[[ ${#FAILED_TASKS[@]} -gt 0 ]] && echo "  Failed: ${FAILED_TASKS[*]}"
echo "${B}────────────────────────────────────────${N}"
[[ $VERBOSE -eq 0 && $FAIL -gt 0 ]] && echo "${D}  re-run with -v to see why${N}"
echo
exit $(( FAIL > 0 ))
