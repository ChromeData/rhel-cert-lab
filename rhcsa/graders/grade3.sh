#!/usr/bin/env bash
#
# RHCSA practice grader - Set 3
#
#   sudo bash grade3.sh          grade everything
#   sudo bash grade3.sh -t 41    grade only task 41
#   sudo bash grade3.sh -v       show why each check failed

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

echo; echo "${B}=== RHCSA Practice Grader - Set 3 ===${N}"; echo "${D}host: $(hostname)${N}"; echo

# ------------------------------------------------------------- T31 networking
if want 31; then
  task 31 "Networking: 192.168.56.150, DNS order, hostname server3"
  checkv "static hostname" "server3.lab.example.com" "$(hostnamectl --static 2>/dev/null)"
  ip -4 addr show 2>/dev/null | grep -q '192\.168\.56\.150/24' || fails "192.168.56.150/24 not live"
  ip route 2>/dev/null | grep -q 'default via 192\.168\.56\.1'  || fails "gateway is not 192.168.56.1"
  # Dual-homed box: scan every active profile for the one carrying the target address.
  hit=""
  while IFS=: read -r cname cdev; do
    [[ -z "$cname" || "$cdev" == "lo" ]] && continue
    p=$(nmcli -t -g ipv4.method,ipv4.addresses con show "$cname" 2>/dev/null)
    grep -q '192\.168\.56\.150/24' <<<"$p" || continue
    hit="$cname"
    grep -q '^manual' <<<"$p" || fails "ipv4.method is not manual in profile '$cname'"
    d=$(nmcli -g ipv4.dns con show "$cname" 2>/dev/null)
    [[ "$d" == 8.8.8.8* ]] || fails "DNS order wrong - 8.8.8.8 must be first (got '$d')"
    grep -q '192\.168\.56\.1' <<<"$d" || fails "192.168.56.1 missing from DNS list"
    break
  done < <(nmcli -t -g NAME,DEVICE con show --active 2>/dev/null)
  [[ -n "$hit" ]] || fails "no active NM profile carries 192.168.56.150/24 - won't survive reboot"
  report
fi

# ------------------------------------------------------------------ T32 users
if want 32; then
  task 32 "dbadmin / svcbackup / intern"
  getent group dba >/dev/null 2>&1 || fails "group 'dba' does not exist"
  if ! id dbadmin >/dev/null 2>&1; then fails "dbadmin missing"
  else
    checkv "dbadmin UID" "2500" "$(id -u dbadmin)"
    checkv "dbadmin primary group" "dba" "$(id -gn dbadmin)"
    checkv "dbadmin shell" "/bin/bash" "$(getent passwd dbadmin | cut -d: -f7)"
  fi
  if ! id svcbackup >/dev/null 2>&1; then fails "svcbackup missing"
  else
    u=$(id -u svcbackup); [[ "$u" -lt 1000 ]] || fails "svcbackup UID $u is not a system UID (<1000)"
    case "$(getent passwd svcbackup | cut -d: -f7)" in */nologin|*/false) ;; *) fails "svcbackup shell is interactive";; esac
    hd=$(getent passwd svcbackup | cut -d: -f6)
    [[ -d "$hd" ]] && fails "svcbackup home dir exists at $hd (should not)"
  fi
  if ! id intern >/dev/null 2>&1; then fails "intern missing"
  else
    e=$(chage -l intern 2>/dev/null | grep -i 'account expires' | sed 's/.*: *//')
    grep -Eqi 'jan.*01.*2027|2027-01-01' <<<"$e" || fails "intern expiry is '$e' (want 2027-01-01)"
  fi
  for u in dbadmin intern; do
    h=$(getent shadow "$u" 2>/dev/null | cut -d: -f2)
    case "$h" in ""|"!"*|"*"|"!!") fails "$u has no usable password" ;;
      \$6\$*) s=$(cut -d'$' -f3 <<<"$h")
        [[ "$(openssl passwd -6 -salt "$s" 'Passw0rd!23' 2>/dev/null)" == "$h" ]] || fails "$u password mismatch" ;;
    esac
  done
  report
fi

# --------------------------------------------------------------- T33 archives
if want 33; then
  task 33 "tar.gz backup and extraction"
  A=/root/etcbackup.tar.gz
  if [[ ! -f "$A" ]]; then fails "$A does not exist"
  else
    file "$A" 2>/dev/null | grep -qi 'gzip' || fails "$A is not gzip-compressed"
    l=$(tar tzf "$A" 2>/dev/null)
    for f in hosts fstab passwd; do grep -q "etc/$f" <<<"$l" || fails "$f missing from archive"; done
  fi
  for f in hosts fstab passwd; do
    [[ -f "/tmp/restore/etc/$f" ]] || fails "/tmp/restore/etc/$f not extracted"
  done
  report
fi

# ------------------------------------------------------------------ T34 links
if want 34; then
  task 34 "Hard and symbolic links in /opt/links"
  H=/opt/links/hard-fstab; S=/opt/links/soft-fstab
  if [[ ! -e "$H" ]]; then fails "$H missing"
  else
    [[ -L "$H" ]] && fails "$H is a SYMlink - must be a hard link"
    [[ "$(stat -c %i "$H" 2>/dev/null)" == "$(stat -c %i /etc/fstab 2>/dev/null)" ]] \
      || fails "$H does not share an inode with /etc/fstab"
  fi
  [[ -L "$S" ]] || fails "$S is not a symbolic link"
  [[ "$(readlink "$S" 2>/dev/null)" == "/etc/fstab" ]] || fails "$S does not point at /etc/fstab"
  [[ -s /opt/links/NOTES.txt ]] || fails "/opt/links/NOTES.txt missing or empty"
  report
fi

# ------------------------------------------------------------------ T35 umask
if want 35; then
  task 35 "System-wide umask 027 for login shells"
  grep -rhqE '^[[:space:]]*umask[[:space:]]+0?27' /etc/profile /etc/profile.d/* /etc/bashrc 2>/dev/null \
    || fails "umask 027 not set in /etc/profile, /etc/profile.d/, or /etc/bashrc"
  m=$(bash -lc 'umask' 2>/dev/null)
  [[ "$m" == "0027" || "$m" == "027" ]] || fails "login shell umask is $m (want 0027)"
  report
fi

# ------------------------------------------------------------ T36 sticky dir
if want 36; then
  task 36 "/srv/dropbox - sticky bit, dba group"
  if [[ ! -d /srv/dropbox ]]; then fails "/srv/dropbox does not exist"
  else
    mode=$(stat -c '%a' /srv/dropbox)
    [[ "${mode:0:1}" == "1" || "${mode:0:1}" == "3" || "${mode:0:1}" == "7" ]] \
      || fails "sticky bit not set (mode $mode) - users could delete each other's files"
    [[ "${mode: -3}" == "777" || "${mode: -3}" == "770" ]] || fails "mode ${mode: -3} won't let users create files"
    checkv "group owner" "dba" "$(stat -c '%G' /srv/dropbox)"
  fi
  report
fi

# ------------------------------------------------------------------- T37 find
if want 37; then
  task 37 "/root/bigrecent.txt - /etc files >100KB modified in 30 days"
  F=/root/bigrecent.txt
  if [[ ! -f "$F" ]]; then fails "$F does not exist"
  else
    expected=$(find /etc -type f -size +100k -mtime -30 2>/dev/null | sort)
    actual=$(sort "$F" 2>/dev/null | grep -v '^$')
    if [[ -z "$expected" ]]; then
      [[ -z "$actual" ]] || fails "no matching files exist but $F is not empty"
    else
      [[ "$expected" == "$actual" ]] || fails "contents differ from 'find /etc -type f -size +100k -mtime -30'"
    fi
  fi
  report
fi

# ----------------------------------------------------------------- T38 sysctl
if want 38; then
  task 38 "net.ipv4.ip_forward=1 via drop-in"
  checkv "runtime value" "1" "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
  if ! grep -rhqE '^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=[[:space:]]*1' /etc/sysctl.d/ /usr/lib/sysctl.d/ 2>/dev/null; then
    fails "not set in a /etc/sysctl.d/ drop-in - won't persist"
  fi
  grep -qE '^[[:space:]]*net\.ipv4\.ip_forward' /etc/sysctl.conf 2>/dev/null \
    && fails "set in /etc/sysctl.conf - task asked for a drop-in file instead"
  report
fi

# ----------------------------------------------------------------- T39 target
if want 39; then
  task 39 "Default target = multi-user.target"
  checkv "default target" "multi-user.target" "$(systemctl get-default 2>/dev/null)"
  report
fi

# ------------------------------------------------------------------- T40 mask
if want 40; then
  task 40 "httpd installed but masked"
  rpm -q httpd >/dev/null 2>&1 || fails "httpd is not installed"
  s=$(systemctl is-enabled httpd 2>&1)
  [[ "$s" == "masked" ]] || fails "httpd is '$s', not masked"
  [[ -L /etc/systemd/system/httpd.service ]] || fails "no mask symlink in /etc/systemd/system"
  systemctl start httpd >/dev/null 2>&1 && fails "systemctl start httpd SUCCEEDED - not properly masked"
  report
fi

# --------------------------------------------------------------- T41 swapfile
if want 41; then
  task 41 "1 GiB swap FILE at /swapfile, persistent"
  if [[ ! -f /swapfile ]]; then fails "/swapfile does not exist"
  else
    sz=$(stat -c %s /swapfile)
    (( sz > 1020000000 && sz < 1130000000 )) || fails "/swapfile is $((sz/1024/1024))MB (want ~1024MB)"
    p=$(stat -c '%a' /swapfile)
    [[ "$p" == "600" ]] || fails "/swapfile mode is $p (must be 600 or swapon warns)"
  fi
  swapon --show=NAME --noheadings 2>/dev/null | grep -qx '/swapfile' || fails "/swapfile is not active swap"
  [[ $(swapon --show --noheadings 2>/dev/null | wc -l) -ge 2 ]] || fails "original swap no longer active"
  grep -Eq '^[^#]*/swapfile[[:space:]]+(none|swap)[[:space:]]+swap' /etc/fstab 2>/dev/null \
    || fails "/swapfile not in /etc/fstab"
  report
fi

# ------------------------------------------------------------------- T42 LVM
if want 42; then
  task 42 "vgapp / lvapp 768M ext4 at /srv/app with nodev"
  if ! vgs vgapp >/dev/null 2>&1; then fails "volume group vgapp missing"
  else
    pe=$(vgs --noheadings -o vg_extent_size --units m vgapp 2>/dev/null | tr -d ' m')
    [[ "${pe%%.*}" == "16" ]] || fails "PE size is ${pe}M (want 16M)"
  fi
  if lvs vgapp/lvapp >/dev/null 2>&1; then
    sz=$(lvs --noheadings -o lv_size --units m vgapp/lvapp | tr -d ' m')
    awk -v s="${sz%%.*}" 'BEGIN{exit !(s>=512 && s<=784)}' || fails "lvapp is ${sz}M (768M, or 512M after T43)"
  else fails "logical volume lvapp missing"; fi
  if findmnt -n /srv/app >/dev/null 2>&1; then
    checkv "/srv/app fstype" "ext4" "$(findmnt -n -o FSTYPE /srv/app)"
    findmnt -n -o OPTIONS /srv/app | grep -q nodev || fails "nodev option not active"
  else fails "/srv/app not mounted"; fi
  grep -Eq '^[^#]*[[:space:]]/srv/app[[:space:]]' /etc/fstab 2>/dev/null || fails "/srv/app not in /etc/fstab"
  report
fi

# -------------------------------------------------------------- T43 LV shrink
if want 43; then
  task 43 "lvapp shrunk to 512M + snapshot lvapp-snap"
  if ! lvs vgapp/lvapp >/dev/null 2>&1; then fails "vgapp/lvapp missing"
  else
    sz=$(lvs --noheadings -o lv_size --units m vgapp/lvapp | tr -d ' m')
    awk -v s="${sz%%.*}" 'BEGIN{exit !(s>=512 && s<=528)}' || fails "lvapp is ${sz}M (want 512M)"
    findmnt -n /srv/app >/dev/null 2>&1 || fails "/srv/app no longer mounted - shrink damaged it"
  fi
  if ! lvs vgapp/lvapp-snap >/dev/null 2>&1; then fails "snapshot lvapp-snap missing"
  else
    lvs --noheadings -o lv_attr vgapp/lvapp-snap 2>/dev/null | grep -q '^[[:space:]]*s' \
      || fails "lvapp-snap is not actually a snapshot volume"
  fi
  report
fi

# --------------------------------------------------------- T44 SELinux port
if want 44; then
  task 44 "httpd on port 8088 with SELinux enforcing"
  checkv "SELinux mode" "Enforcing" "$(getenforce 2>/dev/null)"
  s=$(systemctl is-enabled httpd 2>&1); [[ "$s" == "masked" ]] && fails "httpd still masked (unmask it first)"
  systemctl is-active httpd >/dev/null 2>&1 || fails "httpd not running"
  grep -rhqE '^[[:space:]]*Listen[[:space:]]+8088' /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/* 2>/dev/null \
    || fails "no 'Listen 8088' in httpd config"
  semanage port -l 2>/dev/null | grep -E '^http_port_t' | grep -q '8088' \
    || fails "8088 not labelled http_port_t (semanage port -a -t http_port_t -p tcp 8088)"
  curl -fsS --max-time 5 http://localhost:8088/ >/dev/null 2>&1 || fails "curl to localhost:8088 failed"
  report
fi

# ------------------------------------------------------------------- T45 boot
if want 45; then
  task 45 "fstab recovery - system boots clean"
  if ! findmnt --verify --verbose >/dev/null 2>&1; then
    fails "findmnt --verify reports problems in /etc/fstab"
  fi
  bad=0
  while read -r src mnt _; do
    [[ "$src" =~ ^# || -z "$src" ]] && continue
    case "$src" in
      UUID=*) blkid -U "${src#UUID=}" >/dev/null 2>&1 || { fails "fstab references missing UUID: ${src#UUID=}"; bad=1; } ;;
    esac
  done < <(grep -vE '^\s*#|^\s*$' /etc/fstab 2>/dev/null)
  systemctl is-system-running 2>/dev/null | grep -Eq 'running|degraded' \
    || fails "system is not in a running state"
  up=$(cut -d. -f1 /proc/uptime); [[ "$up" -lt 86400 ]] || fails "uptime > 1 day - reboot to prove recovery"
  [[ $bad -eq 0 ]] || true
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
