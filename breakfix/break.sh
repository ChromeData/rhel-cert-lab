#!/usr/bin/env bash
#
# break.sh — sabotage this system in a realistic way, then go fix it.
#
#   break.sh                 break something random (level 1)
#   break.sh -l 2            harder
#   break.sh -l 3            nasty
#   break.sh -f web-403      break one specific thing
#   break.sh --list          show every fault
#   break.sh --check         did you fix it?
#   break.sh --reveal        give up; show what was done
#   break.sh --restore       undo everything
#
# Every fault here is something that actually happens on real systems: a context
# lost to a careless mv, a firewall rule that was never made permanent, a unit
# someone masked in 2019 and forgot. You get no hint about which one fired.
#
# The point is diagnosis, not recall. There is no list of commands to memorise —
# you have to read the system and work out what changed.

set -uo pipefail
[[ $EUID -ne 0 ]] && { echo "Run as root."; exit 1; }

STATE=/var/lib/breakfix
mkdir -p "$STATE"
ACTIVE="$STATE/active"

if [[ -t 1 ]]; then R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else R=""; G=""; Y=""; B=""; D=""; N=""; fi

# ---------------------------------------------------------------- fault table
# id | level | one-line symptom the user would report
FAULTS="
web-403|1|The web server is up but every page returns 403 Forbidden.
web-firewall|1|The website works from the server itself but nobody else can reach it.
svc-masked|1|A service refuses to start and gives a strange error.
cron-silent|2|A cron job stopped producing output. Nothing in the obvious place.
fstab-uuid|2|After the last reboot the machine came up in emergency mode.
ssh-locked|2|SSH refuses key logins and falls back to password.
dns-broken|2|Name resolution fails but the network is otherwise fine.
selinux-port|3|A service was moved to a non-standard port and now will not start.
perm-shadow|3|Users cannot log in. Nothing was changed in their accounts.
lvm-unmounted|3|An application is writing to the wrong filesystem and disks look wrong.
"

list_faults() {
  echo "${B}Available faults${N}"
  echo "$FAULTS" | while IFS='|' read -r id lvl desc; do
    [[ -z "$id" ]] && continue
    printf "  ${Y}%-14s${N} L%s  %s\n" "$id" "$lvl" "$desc"
  done
}

save() { echo "$1" >> "$STATE/undo.log"; }

# ------------------------------------------------------------------- breakers
apply_fault() {
  case "$1" in
    web-403)
      rpm -q httpd &>/dev/null || dnf -y install httpd &>/dev/null
      mkdir -p /var/www/html
      echo "RHCSA-OK" > /var/www/html/index.html
      systemctl enable --now httpd &>/dev/null
      firewall-cmd --permanent --add-service=http &>/dev/null; firewall-cmd --reload &>/dev/null
      # the classic: file created in /root then moved in, carrying the wrong context
      chcon -t admin_home_t /var/www/html/index.html
      save "restorecon -Rv /var/www/html"
      ;;
    web-firewall)
      rpm -q httpd &>/dev/null || dnf -y install httpd &>/dev/null
      echo "RHCSA-OK" > /var/www/html/index.html
      restorecon -Rv /var/www/html &>/dev/null
      systemctl enable --now httpd &>/dev/null
      firewall-cmd --permanent --remove-service=http &>/dev/null
      firewall-cmd --reload &>/dev/null
      save "firewall-cmd --permanent --add-service=http; firewall-cmd --reload"
      ;;
    svc-masked)
      systemctl mask --now chronyd &>/dev/null
      save "systemctl unmask chronyd; systemctl enable --now chronyd"
      ;;
    cron-silent)
      systemctl enable --now crond &>/dev/null
      echo '*/2 * * * * /usr/local/bin/heartbeat >> /var/log/heartbeat.log 2>&1' | crontab -
      cat > /usr/local/bin/heartbeat <<'EOF'
#!/bin/bash
date >> /var/log/heartbeat.log
EOF
      chmod 0644 /usr/local/bin/heartbeat      # not executable — the actual fault
      save "chmod +x /usr/local/bin/heartbeat"
      ;;
    fstab-uuid)
      cp /etc/fstab "$STATE/fstab.bak"
      echo "UUID=00000000-dead-beef-0000-000000000000 /srv/data xfs defaults 0 0" >> /etc/fstab
      save "cp $STATE/fstab.bak /etc/fstab"
      ;;
    ssh-locked)
      mkdir -p /root/.ssh
      chmod 0777 /root/.ssh                    # sshd refuses world-writable
      [[ -f /root/.ssh/authorized_keys ]] && chmod 0644 /root/.ssh/authorized_keys
      save "chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys"
      ;;
    dns-broken)
      c=$(nmcli -t -g NAME,DEVICE con show --active | awk -F: '$2!="lo"{print $1; exit}')
      echo "$c" > "$STATE/dnsconn"
      nmcli con mod "$c" ipv4.dns 10.255.255.1 &>/dev/null
      nmcli con up "$c" &>/dev/null
      save "nmcli con mod $c ipv4.dns 192.168.56.1; nmcli con up $c"
      ;;
    selinux-port)
      rpm -q httpd &>/dev/null || dnf -y install httpd &>/dev/null
      systemctl unmask httpd &>/dev/null
      sed -i 's/^Listen 80$/Listen 8088/' /etc/httpd/conf/httpd.conf
      semanage port -d -t http_port_t -p tcp 8088 &>/dev/null   # ensure NOT labelled
      systemctl restart httpd &>/dev/null
      save "semanage port -a -t http_port_t -p tcp 8088; systemctl restart httpd"
      ;;
    perm-shadow)
      cp -a /etc/shadow "$STATE/shadow.bak"
      chmod 0644 /etc/shadow                   # wrong mode; SELinux/pam complain
      chown root:root /etc/shadow
      save "chmod 000 /etc/shadow"
      ;;
    lvm-unmounted)
      if lvs vgdata/lvdata &>/dev/null; then
        umount /data &>/dev/null
        cp /etc/fstab "$STATE/fstab.lvm.bak"
        sed -i '\|/data|d' /etc/fstab
        save "cp $STATE/fstab.lvm.bak /etc/fstab; mount -a"
      else
        echo "  (skipped: vgdata/lvdata does not exist — do the LVM task first)"
        return 1
      fi
      ;;
    *) echo "unknown fault: $1"; return 1 ;;
  esac
}

# -------------------------------------------------------------------- checker
check_fault() {
  case "$1" in
    web-403)        curl -fsS --max-time 5 http://localhost/ 2>/dev/null | grep -q RHCSA-OK ;;
    web-firewall)   firewall-cmd --permanent --list-services 2>/dev/null | grep -qw http ;;
    svc-masked)     [[ "$(systemctl is-enabled chronyd 2>&1)" != "masked" ]] && systemctl is-active chronyd &>/dev/null ;;
    cron-silent)    [[ -x /usr/local/bin/heartbeat ]] ;;
    fstab-uuid)     ! grep -q "00000000-dead-beef" /etc/fstab && mount -a &>/dev/null ;;
    ssh-locked)     [[ "$(stat -c %a /root/.ssh)" == "700" ]] ;;
    dns-broken)     ! nmcli -g ipv4.dns con show "$(cat $STATE/dnsconn 2>/dev/null)" 2>/dev/null | grep -q 10.255.255.1 ;;
    selinux-port)   semanage port -l 2>/dev/null | grep '^http_port_t' | grep -q 8088 && systemctl is-active httpd &>/dev/null ;;
    perm-shadow)    [[ "$(stat -c %a /etc/shadow)" == "000" ]] ;;
    lvm-unmounted)  findmnt -n /data &>/dev/null && grep -q "/data" /etc/fstab ;;
    *) return 1 ;;
  esac
}

symptom_of() { echo "$FAULTS" | grep "^$1|" | cut -d'|' -f3; }

# ----------------------------------------------------------------------- main
LEVEL=1; FAULT=""; MODE="break"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l) LEVEL="$2"; shift 2 ;;
    -f) FAULT="$2"; shift 2 ;;
    --list) list_faults; exit 0 ;;
    --check) MODE="check"; shift ;;
    --reveal) MODE="reveal"; shift ;;
    --restore) MODE="restore"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

case "$MODE" in
  check)
    [[ -f "$ACTIVE" ]] || { echo "Nothing is broken. Run break.sh first."; exit 0; }
    f=$(cat "$ACTIVE")
    if check_fault "$f"; then
      echo; echo "  ${G}FIXED${N} — $(symptom_of "$f")"
      echo "  ${D}fault was: $f${N}"
      echo; echo "  ${Y}Now reboot and run --check again. A fix that does not survive is not a fix.${N}"; echo
    else
      echo; echo "  ${R}STILL BROKEN${N}"
      echo "  ${D}symptom: $(symptom_of "$f")${N}"; echo
      exit 1
    fi
    ;;
  reveal)
    [[ -f "$ACTIVE" ]] || { echo "Nothing is broken."; exit 0; }
    f=$(cat "$ACTIVE")
    echo; echo "  fault : ${Y}$f${N}"
    echo "  symptom: $(symptom_of "$f")"
    echo "  undo   : ${D}$(tail -1 "$STATE/undo.log" 2>/dev/null)${N}"; echo
    ;;
  restore)
    [[ -f "$STATE/undo.log" ]] || { echo "Nothing to undo."; exit 0; }
    while read -r cmd; do [[ -n "$cmd" ]] && eval "$cmd" &>/dev/null; done < "$STATE/undo.log"
    rm -f "$STATE/undo.log" "$ACTIVE"
    echo "Restored."
    ;;
  break)
    if [[ -z "$FAULT" ]]; then
      mapfile -t pool < <(echo "$FAULTS" | awk -F'|' -v L="$LEVEL" 'NF && $2<=L {print $1}')
      [[ ${#pool[@]} -eq 0 ]] && { echo "no faults at level $LEVEL"; exit 1; }
      FAULT="${pool[RANDOM % ${#pool[@]}]}"
    fi
    echo; echo "  ${B}Breaking something...${N}"
    if apply_fault "$FAULT"; then
      echo "$FAULT" > "$ACTIVE"
      echo
      echo "  ${R}TICKET${N}"
      echo "  $(symptom_of "$FAULT")"
      echo
      echo "  ${D}Diagnose it. No hints. When you think it's fixed:${N}"
      echo "  ${D}  break.sh --check${N}"
      echo
    else
      echo "  could not apply $FAULT"; exit 1
    fi
    ;;
esac
