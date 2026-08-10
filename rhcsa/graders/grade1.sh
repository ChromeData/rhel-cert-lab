#!/usr/bin/env bash
#
# RHCSA practice grader - Set 1
#
#   sudo bash grade.sh          grade everything
#   sudo bash grade.sh -t 8     grade only task 8
#   sudo bash grade.sh -v       show why each check failed
#
# Checks LIVE SYSTEM STATE, not command history - same as the real grader.
# Run it once, then REBOOT and run it again. The second run is the real score.

set -uo pipefail

VERBOSE=0
ONLY=""
while getopts "t:vh" opt; do
  case $opt in
    t) ONLY="$OPTARG" ;;
    v) VERBOSE=1 ;;
    h) sed -n '2,12p' "$0"; exit 0 ;;
    *) exit 2 ;;
  esac
done

[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

if [[ -t 1 ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; D=""; N=""
fi

PASS=0; FAIL=0; TOTAL=0; FAILED_TASKS=()
CUR_ID=""; CUR_NAME=""; CUR_ERRS=()

task() {   # task <id> <name>
  CUR_ID="$1"; CUR_NAME="$2"; CUR_ERRS=()
}

# ok <condition-already-evaluated> is awkward in bash; use check <msg> <cmd...>
check() {  # check "<description>" <command...>   -> records failure if command fails
  local desc="$1"; shift
  if ! "$@" >/dev/null 2>&1; then CUR_ERRS+=("$desc"); fi
}
checkv() { # checkv "<description>" <expected> <actual>
  local desc="$1" want="$2" got="$3"
  [[ "$want" == "$got" ]] || CUR_ERRS+=("$desc (want '$want', got '${got:-<empty>}')")
}
fails() { CUR_ERRS+=("$1"); }

report() {
  TOTAL=$((TOTAL+1))
  if [[ ${#CUR_ERRS[@]} -eq 0 ]]; then
    PASS=$((PASS+1))
    printf "  %sPASS%s  T%-3s %s\n" "$G" "$N" "$CUR_ID" "$CUR_NAME"
  else
    FAIL=$((FAIL+1)); FAILED_TASKS+=("T$CUR_ID")
    printf "  %sFAIL%s  T%-3s %s\n" "$R" "$N" "$CUR_ID" "$CUR_NAME"
    if [[ $VERBOSE -eq 1 ]]; then
      for e in "${CUR_ERRS[@]}"; do printf "        %s- %s%s\n" "$D" "$e" "$N"; done
    fi
  fi
}

want_task() { [[ -z "$ONLY" || "$ONLY" == "$1" || "$ONLY" == "$((10#$1))" ]]; }

# helper: is a systemd unit both enabled and active?
unit_ok() {
  systemctl is-enabled "$1" >/dev/null 2>&1 && systemctl is-active "$1" >/dev/null 2>&1
}

echo
echo "${B}=== RHCSA Practice Grader - Set 1 ===${N}"
echo "${D}host: $(hostname) | uptime: $(uptime -p 2>/dev/null || echo n/a)${N}"
echo

# ---------------------------------------------------------------- T01 network
if want_task 01; then
  task 01 "Networking (static IP, gw, DNS, hostname, secondary IP)"

  checkv "static hostname" "node1.domain40.example.com" "$(hostnamectl --static 2>/dev/null)"

  ip -4 addr show 2>/dev/null | grep -q '192\.168\.56\.101/24' \
    || fails "192.168.56.101/24 not live on any interface"
  ip -4 addr show 2>/dev/null | grep -q '10\.0\.0\.5/24' \
    || fails "secondary 10.0.0.5/24 not live"
  ip route 2>/dev/null | grep -q 'default via 192\.168\.56\.1' \
    || fails "default gateway is not 192.168.56.1"

  # Persistence: the values must live in a NetworkManager profile, not just runtime.
  # Search EVERY active profile - the box is dual-homed (NAT + host-only), so we must
  # not assume the first active connection is the one the task is about.
  hit=""
  while IFS=: read -r cname cdev; do
    [[ -z "$cname" || "$cdev" == "lo" ]] && continue
    props=$(nmcli -t -g ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns con show "$cname" 2>/dev/null)
    grep -q '192\.168\.56\.101/24' <<<"$props" || continue
    hit="$cname"
    grep -q '^manual'         <<<"$props" || fails "ipv4.method is not manual in profile '$cname'"
    grep -q '10\.0\.0\.5/24'  <<<"$props" || fails "secondary 10.0.0.5/24 not in profile '$cname'"
    grep -q '192\.168\.56\.1' <<<"$props" || fails "gateway/DNS 192.168.56.1 not in profile '$cname'"
    break
  done < <(nmcli -t -g NAME,DEVICE con show --active 2>/dev/null)
  [[ -n "$hit" ]] || fails "no active NM profile carries 192.168.56.101/24 - config will not survive reboot"
  report
fi

# ------------------------------------------------------------------ T02 users
if want_task 02; then
  task 02 "Users harry/natasha in admin group, tom non-interactive"

  getent group admin >/dev/null 2>&1 || fails "group 'admin' does not exist"
  for u in harry natasha tom; do
    id "$u" >/dev/null 2>&1 || fails "user '$u' does not exist"
  done
  for u in harry natasha; do
    if id "$u" >/dev/null 2>&1; then
      id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx admin \
        || fails "'$u' is not in supplementary group admin"
    fi
  done
  if id tom >/dev/null 2>&1; then
    tomsh=$(getent passwd tom | cut -d: -f7)
    case "$tomsh" in
      */nologin|*/false) ;;
      *) fails "tom's shell is '$tomsh' (want /sbin/nologin or /bin/false)" ;;
    esac
  fi
  report
fi

# ------------------------------------------------------------------ T03 alex
if want_task 03; then
  task 03 "User alex, UID 1234, password alex111"

  if ! id alex >/dev/null 2>&1; then
    fails "user 'alex' does not exist"
  else
    checkv "UID" "1234" "$(id -u alex 2>/dev/null)"
    hash=$(getent shadow alex 2>/dev/null | cut -d: -f2)
    case "$hash" in
      ""|"!"*|"*"|"!!") fails "no usable password set (account locked or empty)" ;;
      \$6\$*)
        salt=$(cut -d'$' -f3 <<<"$hash")
        calc=$(openssl passwd -6 -salt "$salt" "alex111" 2>/dev/null)
        [[ "$calc" == "$hash" ]] || fails "password does not match 'alex111'"
        ;;
      *)
        # yescrypt et al - openssl can't recompute these; verify only that one is set.
        [[ $VERBOSE -eq 1 ]] && echo "        ${D}note: hash type $(cut -d'$' -f2 <<<"$hash") not verifiable here; password is set${N}"
        ;;
    esac
  fi
  report
fi

# --------------------------------------------------------------- T04 setgid dir
if want_task 04; then
  task 04 "/home/admins collaborative directory"

  if [[ ! -d /home/admins ]]; then
    fails "/home/admins does not exist or is not a directory"
  else
    grp=$(stat -c '%G' /home/admins)
    mode=$(stat -c '%a' /home/admins)
    checkv "group owner" "admin" "$grp"
    # want setgid + group rwx + other ---  => 2770 (2750 fails: group needs write)
    [[ "$mode" == "2770" ]] || fails "mode is $mode (want 2770: setgid, group rwx, other none)"
    [[ "${mode: -1}" == "0" ]] || fails "'other' has access - must be 0"
  fi
  report
fi

# ------------------------------------------------------------------- T05 cron
if want_task 05; then
  task 05 "Cron: echo hello at 14:23 daily"

  unit_ok crond || fails "crond is not enabled+active"

  # Gather every place a root cron job could legitimately live, then match
  # schedule AND command on the SAME line.
  cronsrc=$( { crontab -l -u root 2>/dev/null
               cat /etc/crontab /etc/cron.d/* 2>/dev/null; } )
  if ! grep -E '^[[:space:]]*23[[:space:]]+14[[:space:]]+\*[[:space:]]+\*[[:space:]]+\*' <<<"$cronsrc" \
       | grep -q 'echo.*hello'; then
    fails "no '23 14 * * *' entry running 'echo hello' in root crontab, /etc/crontab, or /etc/cron.d"
  fi
  report
fi

# --------------------------------------------------------------- T06 find/copy
if want_task 06; then
  task 06 "Files owned by harry copied to /opt/dir"

  if [[ ! -d /opt/dir ]]; then
    fails "/opt/dir does not exist"
  else
    n=$(find /opt/dir -type f -user harry 2>/dev/null | wc -l)
    [[ "$n" -gt 0 ]] || fails "/opt/dir contains no files owned by harry"
    # sanity: did they actually sweep the system, or just touch one file?
    src=$(find / -xdev -type f -user harry -not -path '/opt/dir/*' -not -path '/proc/*' 2>/dev/null | wc -l)
    if [[ "$src" -gt 0 && "$n" -lt "$src" ]]; then
      fails "found $src file(s) owned by harry outside /opt/dir but only $n inside - incomplete copy"
    fi
  fi
  report
fi

# ------------------------------------------------------------------ T07 grep
if want_task 07; then
  task 07 "Lines containing 'abcde' from /etc/testfile -> /tmp/testfile"

  if [[ ! -f /etc/testfile ]]; then
    fails "/etc/testfile missing - create it first (see TASKS.md)"
  elif [[ ! -f /tmp/testfile ]]; then
    fails "/tmp/testfile does not exist"
  else
    expected=$(grep 'abcde' /etc/testfile 2>/dev/null)
    actual=$(cat /tmp/testfile 2>/dev/null)
    [[ "$expected" == "$actual" ]] || fails "/tmp/testfile contents differ from 'grep abcde /etc/testfile'"
  fi
  report
fi

# ------------------------------------------------------------------ T08 swap
if want_task 08; then
  task 08 "2 GiB additional swap, persistent, original swap intact"

  mapfile -t swaps < <(swapon --show=NAME,SIZE --bytes --noheadings 2>/dev/null)
  [[ ${#swaps[@]} -ge 2 ]] || fails "expected 2+ active swap areas (original + new), found ${#swaps[@]}"

  got2g=0
  for s in "${swaps[@]}"; do
    sz=$(awk '{print $2}' <<<"$s")
    # 2 GiB +/- 5%
    if [[ -n "$sz" ]] && (( sz > 2040109466 && sz < 2254857830 )); then got2g=1; fi
  done
  [[ $got2g -eq 1 ]] || fails "no active swap area of ~2 GiB found"

  # Persistence, by UUID specifically
  if ! grep -Eq '^[^#]*\bswap\b' /etc/fstab 2>/dev/null; then
    fails "no swap entry in /etc/fstab"
  else
    grep -E '^[^#]*\bswap\b' /etc/fstab | grep -q '^UUID=' \
      || fails "swap is in fstab but not referenced by UUID"
  fi
  report
fi

# ------------------------------------------------------------------ T09 httpd
if want_task 09; then
  task 09 "Apache serving RHCSA-OK, persistent, reachable"

  unit_ok httpd || fails "httpd is not enabled+active"
  body=$(curl -fsS --max-time 5 http://192.168.56.101/ 2>/dev/null)
  grep -q 'RHCSA-OK' <<<"$body" || fails "http://192.168.56.101/ did not return 'RHCSA-OK'"

  # Firewall must be open in the PERMANENT config, not just runtime.
  if systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --permanent --list-all 2>/dev/null | grep -Eq '(^|[[:space:]])(http|80/tcp)' \
      || fails "http/80 not open in permanent firewalld config"
  fi
  report
fi

# ----------------------------------------------------------------- T10 vsftpd
if want_task 10; then
  task 10 "vsftpd anonymous download from /var/ftp/pub"

  unit_ok vsftpd || fails "vsftpd is not enabled+active"
  [[ -f /var/ftp/pub/README ]] || fails "/var/ftp/pub/README does not exist"
  curl -fsS --max-time 5 ftp://192.168.56.101/pub/README >/dev/null 2>&1 \
    || fails "anonymous FTP fetch of /pub/README failed"
  if systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --permanent --list-all 2>/dev/null | grep -Eq '(^|[[:space:]])(ftp|21/tcp)' \
      || fails "ftp/21 not open in permanent firewalld config"
  fi
  report
fi

# --------------------------------------------------------------- T11 firewall
if want_task 11; then
  task 11 "Reject traffic from 172.25.0.0/16"

  if ! systemctl is-active firewalld >/dev/null 2>&1; then
    fails "firewalld is not running"
  else
    run=$(firewall-cmd --list-all --zone=$(firewall-cmd --get-default-zone 2>/dev/null) 2>/dev/null; firewall-cmd --list-rich-rules 2>/dev/null)
    perm=$(firewall-cmd --permanent --list-all 2>/dev/null; firewall-cmd --permanent --list-rich-rules 2>/dev/null)
    grep -q '172\.25\.0\.0/16' <<<"$run"  || fails "no runtime rule referencing 172.25.0.0/16"
    grep -q '172\.25\.0\.0/16' <<<"$perm" || fails "rule is not in the PERMANENT config - will vanish on reboot"
    grep -Eq 'reject|drop|block' <<<"$run" || fails "rule exists but does not reject/drop"
  fi
  report
fi

# ----------------------------------------------------------------- T12 kernel
if want_task 12; then
  task 12 "Newest kernel is the default boot target"

  if ! command -v grubby >/dev/null 2>&1; then
    fails "grubby not available"
  else
    defk=$(grubby --default-kernel 2>/dev/null)
    newest=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -V | tail -1)
    [[ -n "$defk"   ]] || fails "grubby returned no default kernel"
    [[ -n "$newest" ]] || fails "no kernel packages found via rpm"
    if [[ -n "$defk" && -n "$newest" ]]; then
      grep -q "$newest" <<<"$defk" \
        || fails "default is '$(basename "$defk")' but newest installed is '$newest'"
    fi
    nk=$(rpm -q kernel 2>/dev/null | wc -l)
    [[ "$nk" -ge 2 ]] || fails "only $nk kernel installed - task requires keeping the previous one"
  fi
  report
fi

# ------------------------------------------------------------------- T13 repo
if want_task 13; then
  task 13 "dnf repository 'local' from installation media"

  if ! dnf repolist --enabled 2>/dev/null | awk '{print $1}' | grep -qx 'local'; then
    fails "repo id 'local' is not present and enabled"
  fi
  grep -rhq 'gpgcheck[[:space:]]*=[[:space:]]*0' /etc/yum.repos.d/ 2>/dev/null \
    || fails "gpgcheck=0 not set in any repo file"
  dnf -q --disablerepo='*' --enablerepo='local' list --available >/dev/null 2>&1 \
    || fails "'dnf --enablerepo=local' returned no usable metadata"
  # The backing mount must itself survive a reboot.
  if grep -rhq 'baseurl[[:space:]]*=[[:space:]]*file:///mnt' /etc/yum.repos.d/ 2>/dev/null; then
    findmnt -n /mnt >/dev/null 2>&1 || fails "/mnt is not mounted"
    grep -Eq '^[^#]*[[:space:]]/mnt[[:space:]]' /etc/fstab 2>/dev/null \
      || fails "/mnt mount is not in /etc/fstab - repo breaks on reboot"
  fi
  report
fi

# ---------------------------------------------------------------- T14 SELinux
if want_task 14; then
  task 14 "SELinux enforcing + correct context on web content"

  checkv "current mode" "Enforcing" "$(getenforce 2>/dev/null)"
  grep -Eq '^SELINUX=enforcing' /etc/selinux/config 2>/dev/null \
    || fails "/etc/selinux/config does not set SELINUX=enforcing - reverts on reboot"

  webfile=$(find /var/www/html -maxdepth 1 -type f -name 'index.htm*' 2>/dev/null | head -1)
  if [[ -z "$webfile" ]]; then
    fails "no index.html found under /var/www/html (T09 not done?)"
  else
    ls -Z "$webfile" 2>/dev/null | grep -q 'httpd_sys_content_t' \
      || fails "$webfile is not labelled httpd_sys_content_t"
  fi
  report
fi

# -------------------------------------------------------------------- T15 LVM
if want_task 15; then
  task 15 "LVM: vgdata / lvdata 512M xfs mounted at /data"

  if ! command -v vgs >/dev/null 2>&1; then
    fails "LVM tools not installed"
  else
    vgs vgdata >/dev/null 2>&1 || fails "volume group 'vgdata' does not exist"
    if vgs vgdata >/dev/null 2>&1; then
      pe=$(vgs --noheadings -o vg_extent_size --units m vgdata 2>/dev/null | tr -d ' m')
      [[ "${pe%%.*}" == "8" ]] || fails "PE size is ${pe:-?}M (want 8M)"
    fi
    if ! lvs vgdata/lvdata >/dev/null 2>&1; then
      fails "logical volume 'lvdata' does not exist in vgdata"
    else
      sz=$(lvs --noheadings -o lv_size --units m vgdata/lvdata 2>/dev/null | tr -d ' m')
      # 512 MiB, allow rounding up to the next extent
      awk -v s="${sz%%.*}" 'BEGIN{exit !(s>=512 && s<=520)}' \
        || fails "lvdata is ${sz:-?}M (want 512M)"
    fi
    if ! findmnt -n /data >/dev/null 2>&1; then
      fails "/data is not mounted"
    else
      fstype=$(findmnt -n -o FSTYPE /data 2>/dev/null)
      checkv "/data filesystem" "xfs" "$fstype"
    fi
    grep -Eq '^[^#]*[[:space:]]/data[[:space:]]' /etc/fstab 2>/dev/null \
      || fails "/data is not in /etc/fstab - will not mount on reboot"
  fi
  report
fi

# ---------------------------------------------------------------------- score
echo
PCT=0; [[ $TOTAL -gt 0 ]] && PCT=$(( PASS * 100 / TOTAL ))
if   [[ $PCT -ge 70 ]]; then COL="$G"
elif [[ $PCT -ge 50 ]]; then COL="$Y"
else                         COL="$R"; fi

echo "${B}────────────────────────────────────────${N}"
printf "  Score: %s%d/%d  (%d%%)%s   %s\n" "$COL" "$PASS" "$TOTAL" "$PCT" "$N" \
       "$( [[ $PCT -ge 70 ]] && echo 'passing mark' || echo 'below 70% pass mark' )"
[[ ${#FAILED_TASKS[@]} -gt 0 ]] && echo "  Failed: ${FAILED_TASKS[*]}"
echo "${B}────────────────────────────────────────${N}"
[[ $VERBOSE -eq 0 && $FAIL -gt 0 ]] && echo "${D}  re-run with -v to see why${N}"

if [[ -n "${SUDO_USER:-}" || $EUID -eq 0 ]]; then
  up=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
  if [[ "$up" -gt 900 ]]; then
    echo "${Y}  NOTE: uptime is $((up/60))m. Reboot and grade again -${N}"
    echo "${Y}        persistence bugs only show up on a fresh boot.${N}"
  fi
fi
echo
exit $(( FAIL > 0 ))
