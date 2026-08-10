#!/usr/bin/env bash
#
# RHCSA practice grader - Set 4 (gap closure)
#
#   sudo bash grade4.sh          grade everything
#   sudo bash grade4.sh -t 51    grade only task 51
#   sudo bash grade4.sh -v       show why each check failed

set -uo pipefail

VERBOSE=0; ONLY=""
while getopts "t:vh" opt; do
  case $opt in
    t) ONLY="$OPTARG" ;; v) VERBOSE=1 ;;
    h) sed -n '2,8p' "$0"; exit 0 ;; *) exit 2 ;;
  esac
done
[[ $EUID -ne 0 ]] && { echo "Run as root: sudo bash $0"; exit 1; }

if [[ -t 1 ]]; then R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else R=""; G=""; Y=""; B=""; D=""; N=""; fi

PASS=0; FAIL=0; TOTAL=0; FAILED_TASKS=(); CUR_ID=""; CUR_NAME=""; CUR_ERRS=()
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
want(){ [[ -z "$ONLY" || "$ONLY" == "$1" || "$ONLY" == "$((10#$1))" ]]; }
unit_ok(){ systemctl is-enabled "$1" >/dev/null 2>&1 && systemctl is-active "$1" >/dev/null 2>&1; }

echo; echo "${B}=== RHCSA Practice Grader - Set 4 (gap closure) ===${N}"; echo "${D}host: $(hostname)${N}"; echo

# --------------------------------------------------------------- T46 flatpak
if want 46; then
  task 46 "Flatpak: remote added, app installed then removed"
  if ! command -v flatpak >/dev/null 2>&1; then fails "flatpak not installed"
  else
    flatpak remotes 2>/dev/null | grep -qi 'flathub' || fails "flathub remote not configured"
    # Evidence they actually installed something at some point
    [[ -d /var/lib/flatpak/app || -d /var/lib/flatpak/runtime ]] \
      || fails "no evidence any flatpak was ever installed"
  fi
  report
fi

# --------------------------------------------------------------- T47 ssh keys
if want 47; then
  task 47 "SSH key auth for harry -> node2, passwords disabled on node2"
  if ! id harry >/dev/null 2>&1; then fails "user harry does not exist"
  else
    hd=$(getent passwd harry | cut -d: -f6)
    ls "$hd"/.ssh/id_* >/dev/null 2>&1 || fails "no keypair in $hd/.ssh"
    runuser -l harry -c 'ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 192.168.56.102 true' 2>/dev/null \
      || fails "key-based ssh from harry to node2 failed (BatchMode blocks password fallback)"
    r=$(runuser -l harry -c 'ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 192.168.56.102 "grep -rhE \"^[[:space:]]*PasswordAuthentication\" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null"' 2>/dev/null)
    grep -qiE 'PasswordAuthentication[[:space:]]+no' <<<"$r" || fails "node2 still allows password authentication"
  fi
  report
fi

# ------------------------------------------------------------ T48 SELinux bool
if want 48; then
  task 48 "SELinux boolean httpd_can_network_connect, persistent"
  checkv "SELinux mode" "Enforcing" "$(getenforce 2>/dev/null)"
  v=$(getsebool httpd_can_network_connect 2>/dev/null | awk '{print $3}')
  checkv "httpd_can_network_connect" "on" "$v"
  semanage boolean -l -C 2>/dev/null | grep -q 'httpd_can_network_connect' \
    || fails "boolean not set persistently (needs setsebool -P)"
  F=/root/httpd-booleans.txt
  [[ -s "$F" ]] || fails "$F missing or empty"
  [[ -s "$F" ]] && { grep -q 'httpd' "$F" || fails "$F does not list httpd booleans"; }
  report
fi

# --------------------------------------------------------------- T49 sd timer
if want 49; then
  task 49 "systemd timer hello.timer every 10 minutes"
  [[ -f /etc/systemd/system/hello.service ]] || fails "/etc/systemd/system/hello.service missing"
  [[ -f /etc/systemd/system/hello.timer   ]] || fails "/etc/systemd/system/hello.timer missing"
  if [[ -f /etc/systemd/system/hello.timer ]]; then
    grep -Eqi 'OnCalendar|OnUnitActiveSec|OnBootSec' /etc/systemd/system/hello.timer \
      || fails "timer has no OnCalendar/OnUnitActiveSec directive"
    grep -Eqi '(\*:0/10|OnUnitActiveSec[[:space:]]*=[[:space:]]*10?m|600)' /etc/systemd/system/hello.timer \
      || fails "timer interval does not look like 10 minutes"
  fi
  systemctl is-enabled hello.timer >/dev/null 2>&1 || fails "hello.timer not enabled"
  systemctl is-active  hello.timer >/dev/null 2>&1 || fails "hello.timer not active"
  systemctl list-timers --all 2>/dev/null | grep -q 'hello.timer' || fails "hello.timer not in the timer list"
  report
fi

# -------------------------------------------------------------------- T50 at
if want 50; then
  task 50 "One-time 'at' job queued for 23:55"
  if ! command -v at >/dev/null 2>&1; then fails "at not installed"
  else
    unit_ok atd || fails "atd not enabled+active"
    q=$(atq 2>/dev/null)
    [[ -n "$q" ]] || fails "no jobs in the at queue"
    grep -q '23:55' <<<"$q" || fails "no job queued for 23:55 (queue: ${q:-empty})"
  fi
  report
fi

# ------------------------------------------------------------------ T51 VFAT
if want 51; then
  task 51 "1 GiB VFAT mounted at /mnt/usbsim by UUID"
  if ! findmnt -n /mnt/usbsim >/dev/null 2>&1; then fails "/mnt/usbsim not mounted"
  else
    t=$(findmnt -n -o FSTYPE /mnt/usbsim)
    [[ "$t" == "vfat" ]] || fails "/mnt/usbsim fstype is '$t' (want vfat)"
    sz=$(df -BM --output=size /mnt/usbsim 2>/dev/null | tail -1 | tr -d ' M')
    [[ -n "$sz" && "$sz" -ge 900 && "$sz" -le 1100 ]] || fails "size is ${sz}M (want ~1024M)"
  fi
  l=$(grep -E '^[^#]*[[:space:]]/mnt/usbsim[[:space:]]' /etc/fstab 2>/dev/null)
  [[ -n "$l" ]] || fails "/mnt/usbsim not in /etc/fstab"
  [[ -n "$l" ]] && { grep -q '^UUID=' <<<"$l" || fails "fstab entry does not use UUID="; }
  report
fi

# ------------------------------------------------------------------ T52 IPv6
if want 52; then
  task 52 "Static IPv6 fd00:56::101/64, IPv4 intact"
  ip -6 addr show 2>/dev/null | grep -q 'fd00:56::101' || fails "fd00:56::101 not live"
  ip -4 addr show 2>/dev/null | grep -qE '192\.168\.56\.(101|150)' || fails "IPv4 address was lost"
  hit=""
  while IFS=: read -r cname cdev; do
    [[ -z "$cname" || "$cdev" == "lo" ]] && continue
    nmcli -g ipv6.addresses con show "$cname" 2>/dev/null | grep -q 'fd00:56::101' && { hit="$cname"; break; }
  done < <(nmcli -t -g NAME,DEVICE con show --active 2>/dev/null)
  [[ -n "$hit" ]] || fails "fd00:56::101 not in any active NM profile - won't survive reboot"
  ping6 -c1 -W2 fd00:56::101 >/dev/null 2>&1 || fails "ping6 to own address failed"
  report
fi

# ----------------------------------------------------------------- T53 /etc/hosts
if want 53; then
  task 53 "node2.lab.local and db.lab.local resolve via /etc/hosts"
  for n in node2.lab.local db.lab.local; do
    r=$(getent hosts "$n" 2>/dev/null | awk '{print $1}')
    [[ "$r" == "192.168.56.102" ]] || fails "$n resolves to '${r:-nothing}' (want 192.168.56.102)"
  done
  grep -qE '^[^#]*192\.168\.56\.102' /etc/hosts 2>/dev/null || fails "entry not present in /etc/hosts"
  report
fi

# -------------------------------------------------------------- T54 processes
if want 54; then
  task 54 "CPU hog identified, reniced, killed"
  F=/root/hog.txt
  if [[ ! -s "$F" ]]; then fails "$F missing or empty"
  else
    pid=$(grep -oE '[0-9]+' "$F" | head -1)
    [[ -n "$pid" ]] || fails "$F does not contain a PID"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && fails "PID $pid is still running - it should have been killed"
  fi
  pgrep -f 'while :; do :; done' >/dev/null 2>&1 && fails "a CPU-burner process is still running"
  report
fi

# ------------------------------------------------------------- T55 rescue boot
if want 55; then
  task 55 "Booted into rescue.target once, default unchanged"
  F=/root/rescue-proof.txt
  [[ -s "$F" ]] || fails "$F missing or empty"
  [[ -s "$F" ]] && { grep -q 'multi-user.target' "$F" || fails "$F should contain the output of systemctl get-default"; }
  checkv "default target still" "multi-user.target" "$(systemctl get-default 2>/dev/null)"
  journalctl --list-boots >/dev/null 2>&1 && \
    { [[ $(journalctl --list-boots 2>/dev/null | wc -l) -ge 2 ]] || fails "only one boot recorded - did you actually reboot?"; }
  report
fi

# ----------------------------------------------------------- T56 file transfer
if want 56; then
  task 56 "scp + rsync to node2"
  K=""
  for c in /root/.ssh/id_ed25519 /root/.ssh/id_rsa; do [[ -f "$c" ]] && K="-i $c"; done
  SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 $K"
  if ! $SSH 192.168.56.102 true 2>/dev/null; then
    fails "cannot reach node2 over ssh from root (set up key auth first)"
  else
    $SSH 192.168.56.102 'test -s /root/from-node1.txt' 2>/dev/null \
      || fails "/root/from-node1.txt missing on node2"
    $SSH 192.168.56.102 'test -d /root/sysconfig-copy' 2>/dev/null \
      || fails "/root/sysconfig-copy missing on node2"
    n=$($SSH 192.168.56.102 'ls -1 /root/sysconfig-copy 2>/dev/null | wc -l' 2>/dev/null)
    [[ -n "$n" && "$n" -gt 0 ]] || fails "/root/sysconfig-copy on node2 is empty"
  fi
  report
fi

# ----------------------------------------------------------------- T57 bzip2
if want 57; then
  task 57 "/root/logs.tar.bz2 compressed with bzip2"
  A=/root/logs.tar.bz2
  if [[ ! -f "$A" ]]; then fails "$A does not exist"
  else
    file "$A" 2>/dev/null | grep -qi 'bzip2' || fails "$A is not bzip2 (check with: file $A)"
    tar tjf "$A" >/dev/null 2>&1 || fails "$A is not a readable bzip2 tar archive"
    tar tjf "$A" 2>/dev/null | grep -Eq 'messages|secure' || fails "archive does not contain the log file"
  fi
  report
fi

# ------------------------------------------------------------ T58 kernel args
if want 58; then
  task 58 "Kernel arg added via grubby, then cleanly removed"
  if ! command -v grubby >/dev/null 2>&1; then fails "grubby not available"
  else
    # End state: the arg should be GONE (task says add, verify, then remove)
    if grubby --info=ALL 2>/dev/null | grep -q 'quiet=0'; then
      fails "quiet=0 still present - the task ends with removing it"
    fi
    # Evidence they used grubby at all: entries must still be intact
    n=$(grubby --info=ALL 2>/dev/null | grep -c '^kernel=')
    [[ "$n" -ge 1 ]] || fails "no boot entries found - grubby edits may have damaged them"
    grubby --default-kernel >/dev/null 2>&1 || fails "no default kernel set - bootloader damaged"
  fi
  report
fi

# ------------------------------------------------------- T59 permission repair
if want 59; then
  task 59 "/srv/broken repaired"
  D=/srv/broken; F=$D/data.txt
  if [[ ! -f "$F" ]]; then fails "$F does not exist"
  else
    checkv "file owner" "root"  "$(stat -c '%U' "$F")"
    checkv "file group" "admin" "$(stat -c '%G' "$F")"
    dm=$(stat -c '%a' "$D")
    [[ "${dm: -1}" =~ [15] ]] || fails "/srv/broken not traversable by others (mode $dm)"
    [[ "${dm:0:1}" =~ [0-7] && "${dm: -2:1}" =~ [2367] ]] || fails "group cannot write to /srv/broken (mode $dm)"
    if id harry >/dev/null 2>&1; then
      runuser -u harry -- test -r "$F" 2>/dev/null || fails "harry cannot READ $F"
      runuser -u harry -- test -w "$F" 2>/dev/null || fails "harry cannot WRITE $F"
    fi
  fi
  report
fi

# ------------------------------------------------------------- T60 user switch
if want 60; then
  task 60 "User switching understood and working"
  F=/root/su-difference.txt
  [[ -s "$F" ]] || fails "$F missing or empty"
  [[ -s "$F" ]] && { grep -Eqi 'login|environ|home|profile|-' "$F" || fails "$F does not explain the difference"; }
  if id harry >/dev/null 2>&1; then
    d=$(runuser -l harry -c 'pwd' 2>/dev/null)
    [[ "$d" == "$(getent passwd harry | cut -d: -f6)" ]] || fails "login shell for harry does not land in his home (got '$d')"
  fi
  if id dbadmin >/dev/null 2>&1; then
    sudo -l -U dbadmin >/dev/null 2>&1 || fails "dbadmin has no sudo rules"
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
[[ ${#FAILED_TASKS[@]} -gt 0 ]] && echo "  Failed: ${FAILED_TASKS[*]}"
echo "${B}────────────────────────────────────────${N}"
[[ $VERBOSE -eq 0 && $FAIL -gt 0 ]] && echo "${D}  re-run with -v to see why${N}"
echo
exit $(( FAIL > 0 ))
