# Concise Command Sheet — all 60 tasks

The tightest form I can stand behind. Where a shortcut was non-obvious I tested it on
your actual systems — those are marked **✓tested**.

**Rule I applied:** shorter only when it is *equally* correct. Where terseness costs
reliability I say so and give the longer form instead. Nothing here trades accuracy
for keystrokes.

Adjust device names (`sdb`/`sdc`) to what `lsblk` actually shows.

---

# Exam 1 — Core

### T01 Networking — 3 commands
```bash
nmcli con mod enp0s8 ipv4.method manual ipv4.addresses 192.168.56.101/24,10.0.0.5/24 ipv4.gateway 192.168.56.1 ipv4.dns 192.168.56.1
nmcli con up enp0s8
hostnamectl set-hostname node1.domain40.example.com
```
Comma-separates both addresses instead of a second `+ipv4.addresses` call. **✓tested**

### T02 Users — group FIRST or it fails
```bash
groupadd admin
useradd -G admin harry
useradd -G admin natasha
useradd -s /sbin/nologin tom
```
`useradd -G admin harry` errors with *"group 'admin' does not exist"* if you skip line 1. **✓tested**

### T03 Fixed UID — 2 commands
```bash
useradd -u 1234 alex
echo alex:alex111 | chpasswd
```

### T04 Collaborative dir — **1 command**
```bash
install -d -g admin -m 2770 /home/admins
```
Replaces `mkdir` + `chgrp` + `chmod`. Verified to produce `mode=2770 group=admin`. **✓tested**

### T05 Cron — 2 commands
```bash
systemctl enable --now crond
echo '23 14 * * * /bin/echo hello' | crontab -
```
⚠ `crontab -` **replaces** the whole crontab. Fine when empty; use `crontab -e` if root already has jobs.

### T06 Find and copy — 2 commands
```bash
mkdir -p /opt/dir
find / -type f -user harry -exec cp -at /opt/dir/ {} +
```
`-t` (target first) plus `+` batches into few `cp` calls instead of one per file — much faster than `\;`.

### T07 Filter — **1 command**
```bash
grep abcde /etc/testfile > /tmp/testfile
```

### T08 Swap partition — 4 commands
```bash
echo ',2G,S' | sfdisk /dev/sdb
mkswap /dev/sdb1
echo "UUID=$(blkid -s UUID -o value /dev/sdb1) none swap defaults 0 0" >> /etc/fstab
swapon -a
```
`sfdisk` beats piping keystrokes to `fdisk` — no blind `n/enter/enter/+2G/t/19/w` sequence to get wrong. The `S` sets type Linux swap. Command substitution writes the UUID for you. **✓tested**

Verify: `swapon --show`

### T09 Web server — 5 commands
```bash
dnf -y install httpd
echo RHCSA-OK > /var/www/html/index.html
systemctl enable --now httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```
No `restorecon` needed — a file *created* in `/var/www/html` inherits the right label. You only need it if you `mv` a file in from elsewhere.

### T10 FTP — 5 commands
```bash
dnf -y install vsftpd
echo hello > /var/ftp/pub/README
systemctl enable --now vsftpd
firewall-cmd --permanent --add-service=ftp
firewall-cmd --reload
```

### T11 Firewall reject — 2 commands
```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.25.0.0/16" reject'
firewall-cmd --reload
```
Keep the inner quotes — rich-rule syntax requires them.

### T12 Default kernel — usually 1 command
```bash
grubby --default-kernel
```
Installing a kernel already makes it default on RHEL 9. Only if it's wrong:
```bash
grubby --set-default /boot/vmlinuz-$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -1)
```

### T13 Local repo — 4 commands
```bash
mkdir -p /mnt/dvd
echo '/dev/sr0 /mnt/dvd iso9660 defaults,ro 0 0' >> /etc/fstab
mount -a
printf '[local]\nname=local\nbaseurl=file:///mnt/dvd/BaseOS\nenabled=1\ngpgcheck=0\n' > /etc/yum.repos.d/local.repo
```
`printf` beats a heredoc for a short file. Add a second stanza for AppStream if you want full coverage.

### T14 SELinux — 2 commands
```bash
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
setenforce 1
```
Config file first (persistence), then runtime.

### T15 LVM — 5 commands
```bash
vgcreate -s 8M vgdata /dev/sdc
lvcreate -L 512M -n lvdata vgdata
mkfs.xfs /dev/vgdata/lvdata
mkdir /data
echo "UUID=$(blkid -s UUID -o value /dev/vgdata/lvdata) /data xfs defaults 0 0" >> /etc/fstab && mount -a
```
**No `pvcreate` needed** — `vgcreate` creates the PV automatically. **✓tested**

---

# Exam 2 — Services & Scripting

### T16 Root password recovery — at the console, not SSH
At the GRUB menu press **e**, find the line starting `linux`, append `rd.break`, then **Ctrl-X**.
```bash
mount -o remount,rw /sysroot
chroot /sysroot
passwd
touch /.autorelabel
exit
exit
```
⚠ Forgetting `/.autorelabel` leaves SELinux mislabeled and you cannot log in. Never skip it.

### T17 Script: arguments
```bash
cat > /usr/local/bin/reportuser <<'EOF'
#!/bin/bash
[ $# -eq 0 ] && { echo "Usage: reportuser <username>"; exit 1; }
id "$1" &>/dev/null || { echo "no such user: $1"; exit 2; }
echo "$(id -u "$1") $(id -gn "$1") $(getent passwd "$1" | cut -d: -f7)"
EOF
chmod +x /usr/local/bin/reportuser
```

### T18 Script: loop
```bash
cat > /usr/local/bin/sizes <<'EOF'
#!/bin/bash
[ -d "$1" ] || { echo "not a directory" >&2; exit 1; }
find "$1" -maxdepth 1 -type f -printf '%s %p\n' | sort -rn | awk '{print $2, $1}'
EOF
chmod +x /usr/local/bin/sizes
```
`find -printf` + `sort -rn` does it without a loop at all.

### T19 ACLs — 4 commands
```bash
install -d -g admin /srv/shared
install -o root -g admin -m 644 /dev/null /srv/shared/report.txt
setfacl -m u:harry:rw,u:tom:--- /srv/shared/report.txt
getfacl /srv/shared/report.txt
```
`setfacl -m` takes **comma-separated** entries — one call, not two.

### T20 NFS export — 6 commands
```bash
dnf -y install nfs-utils
mkdir -p /srv/nfsshare && echo data > /srv/nfsshare/file.txt
echo '/srv/nfsshare 192.168.56.0/24(rw,sync)' >> /etc/exports
systemctl enable --now nfs-server
exportfs -ra
firewall-cmd --permanent --add-service=nfs && firewall-cmd --reload
```

### T21 NFS mount (node2) — 2 commands
```bash
mkdir -p /mnt/remote
echo '192.168.56.101:/srv/nfsshare /mnt/remote nfs defaults,_netdev 0 0' >> /etc/fstab && mount -a
```
`_netdev` stops the boot hanging if the server is down — worth the 8 characters.

### T22 autofs (node2) — 4 commands
```bash
dnf -y install autofs
echo '/net /etc/auto.rhcsa' > /etc/auto.master.d/rhcsa.autofs
echo 'shared -rw,_netdev 192.168.56.101:/srv/nfsshare' > /etc/auto.rhcsa
systemctl enable --now autofs
```
Disable the T21 fstab line first or they fight.

### T23 Logs — 3 commands
```bash
journalctl -b _COMM=sshd | grep -i 'fail\|invalid' > /root/failed-logins.txt
mkdir -p /var/log/journal
systemctl restart systemd-journald
```
Creating `/var/log/journal` is all persistence requires — no config edit needed.

### T24 Time — 4 commands
```bash
timedatectl set-timezone America/New_York
echo 'server 192.168.56.1 iburst' >> /etc/chrony.conf
systemctl enable --now chronyd && systemctl restart chronyd
timedatectl set-ntp true
```

### T25 tuned — **1 command**
```bash
tuned-adm profile virtual-guest
```
Persistent by itself. `tuned-adm recommend` answers the second half.

### T26 Rootless container
```bash
loginctl enable-linger harry
su - harry -c 'podman run -d --name webtest registry.access.redhat.com/ubi9/ubi sleep infinity'
su - harry -c 'mkdir -p ~/.config/systemd/user && cd ~/.config/systemd/user && podman generate systemd --new --name webtest --files'
su - harry -c 'systemctl --user daemon-reload && systemctl --user enable --now container-webtest'
```
`enable-linger` is what makes it survive logout/boot. Skipping it is the usual failure.

### T27 Extend LV — **1 command**
```bash
lvextend -r -L 1G /dev/vgdata/lvdata
```
**`-r` resizes the filesystem too.** Replaces `lvextend` + `xfs_growfs`. Works online.

### T28 Second LV — 4 commands
```bash
lvcreate -L 256M -n lvlogs vgdata
mkfs.ext4 /dev/vgdata/lvlogs
mkdir -p /var/log/archive
echo "UUID=$(blkid -s UUID -o value /dev/vgdata/lvlogs) /var/log/archive ext4 defaults,noexec 0 0" >> /etc/fstab && mount -a
```

### T29 Password aging — **1 command**
```bash
chage -M 60 -W 10 -I 7 -d 0 natasha
```
All four requirements in one call. Verify with `chage -l natasha`.

### T30 sudo — 2 commands
```bash
echo '%admin ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/journalctl' > /etc/sudoers.d/admin
visudo -c
```
⚠ **Always** `visudo -c`. A syntax error in sudoers can lock you out of root escalation entirely.

---

# Exam 3 — Variation

### T31 Networking
```bash
nmcli con mod enp0s8 ipv4.method manual ipv4.addresses 192.168.56.150/24 ipv4.gateway 192.168.56.1 ipv4.dns '8.8.8.8 192.168.56.1'
nmcli con up enp0s8
hostnamectl set-hostname server3.lab.example.com
```
DNS order matters — quote the space-separated list to keep 8.8.8.8 first.

### T32 Users
```bash
groupadd dba
useradd -u 2500 -g dba -s /bin/bash dbadmin
useradd -r -M -s /sbin/nologin svcbackup
useradd -e 2027-01-01 intern
echo -e 'dbadmin:Passw0rd!23\nintern:Passw0rd!23' | chpasswd
```
`-r` system account, `-M` no home, `-e` expiry. `chpasswd` takes multiple lines at once.

### T33 Archive — 3 commands
```bash
tar czpf /root/etcbackup.tar.gz /etc/hosts /etc/fstab /etc/passwd
mkdir -p /tmp/restore
tar xzpf /root/etcbackup.tar.gz -C /tmp/restore
```
`p` preserves permissions. `-C` extracts to a directory without cd'ing.

### T34 Links — 4 commands
```bash
mkdir -p /opt/links
ln /etc/fstab /opt/links/hard-fstab
ln -s /etc/fstab /opt/links/soft-fstab
echo 'hard link still works (same inode); symlink breaks (dangling path)' > /opt/links/NOTES.txt
```

### T35 umask — **1 command**
```bash
echo 'umask 027' > /etc/profile.d/umask.sh
```
A drop-in beats editing `/etc/profile`. Test with `bash -lc umask`.

### T36 Sticky dir — **1 command**
```bash
install -d -g dba -m 1770 /srv/dropbox
```
Leading `1` is the sticky bit — users can create but only delete their own.

### T37 find — **1 command**
```bash
find /etc -type f -size +100k -mtime -30 > /root/bigrecent.txt
```

### T38 sysctl — 2 commands
```bash
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-forward.conf
sysctl --system
```

### T39 Default target — 1 command
```bash
systemctl set-default multi-user.target
```
Second half: `systemctl get-default` and `systemctl list-units --type=target --state=active`

### T40 Mask a service — 2 commands
```bash
dnf -y install httpd
systemctl mask --now httpd
```
`--now` stops it at the same time.

### T41 Swap **file** — 5 commands
```bash
dd if=/dev/zero of=/swapfile bs=1M count=1024
chmod 600 /swapfile
mkswap /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab
swapon -a
```
⚠ `chmod 600` **before** `mkswap`, and a swap *file* goes in fstab by **path**, not UUID.

### T42 LVM — 5 commands
```bash
vgcreate -s 16M vgapp /dev/sdb
lvcreate -L 768M -n lvapp vgapp
mkfs.ext4 /dev/vgapp/lvapp
mkdir -p /srv/app
echo "UUID=$(blkid -s UUID -o value /dev/vgapp/lvapp) /srv/app ext4 defaults,nodev 0 0" >> /etc/fstab && mount -a
```

### T43 Shrink + snapshot — 3 commands
```bash
umount /srv/app
lvreduce -r -L 512M /dev/vgapp/lvapp
lvcreate -s -L 128M -n lvapp-snap /dev/vgapp/lvapp && mount -a
```
`-r` shrinks the filesystem first, in the right order. ext4 can shrink; **xfs cannot**.

### T44 SELinux port — 5 commands
```bash
systemctl unmask httpd
sed -i 's/^Listen 80$/Listen 8088/' /etc/httpd/conf/httpd.conf
semanage port -a -t http_port_t -p tcp 8088
systemctl enable --now httpd
firewall-cmd --permanent --add-port=8088/tcp && firewall-cmd --reload
```
If `semanage` is missing: `dnf -y install policycoreutils-python-utils`

### T45 fstab recovery
Break it, reboot, then at the emergency prompt enter the root password and:
```bash
mount -o remount,rw /
vi /etc/fstab
mount -a && systemctl reboot
```
⚠ **`mount -a` before every reboot** after editing fstab. This is the #1 self-inflicted exam failure.

---

# Exam 4 — Gap Closure

### T46 Flatpak
```bash
dnf -y install flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak -y install flathub org.gnome.Calculator
flatpak list
flatpak -y uninstall org.gnome.Calculator
```

### T47 SSH keys — 3 commands
```bash
su - harry -c 'ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519'
su - harry -c 'ssh-copy-id -o StrictHostKeyChecking=no harry@192.168.56.102'
ssh root@192.168.56.102 "echo 'PasswordAuthentication no' > /etc/ssh/sshd_config.d/99-nopw.conf; systemctl reload sshd"
```

### T48 SELinux boolean — 2 commands
```bash
setsebool -P httpd_can_network_connect on
getsebool -a | grep httpd | grep ' on$' > /root/httpd-booleans.txt
```
`-P` is what makes it persistent. Without it you lose it on reboot.

### T49 systemd timer — 4 commands
```bash
printf '[Unit]\nDescription=hello\n[Service]\nType=oneshot\nExecStart=/bin/echo hello\n' > /etc/systemd/system/hello.service
printf '[Unit]\nDescription=hello timer\n[Timer]\nOnUnitActiveSec=10min\nOnBootSec=1min\n[Install]\nWantedBy=timers.target\n' > /etc/systemd/system/hello.timer
systemctl daemon-reload
systemctl enable --now hello.timer
```
⚠ `[Install] WantedBy=timers.target` is mandatory — without it `enable` silently does nothing.

### T50 at — 2 commands
```bash
systemctl enable --now atd
echo 'date > /root/at-ran.txt' | at 23:55
```

### T51 VFAT — 4 commands
```bash
echo ',1G,c' | sfdisk /dev/sdc
mkfs.vfat /dev/sdc1
mkdir -p /mnt/usbsim
echo "UUID=$(blkid -s UUID -o value /dev/sdc1) /mnt/usbsim vfat defaults 0 0" >> /etc/fstab && mount -a
```
`c` is the W95 FAT32 type code. VFAT UUIDs are short (`ABCD-1234`) — that's normal.

### T52 IPv6 — 2 commands
```bash
nmcli con mod enp0s8 ipv6.method manual ipv6.addresses fd00:56::101/64
nmcli con up enp0s8
```

### T53 /etc/hosts — **1 command**
```bash
echo '192.168.56.102 node2.lab.local db.lab.local' >> /etc/hosts
```
Both names on one line — that's the correct format, not two lines.

### T54 Processes — 4 commands
```bash
nohup bash -c 'while :; do :; done' &
ps -eo pid,pcpu,comm --sort=-pcpu | head -3
echo <PID> > /root/hog.txt
renice -n 19 -p <PID> && kill <PID>
```

### T55 Boot to rescue
At GRUB press **e**, append `systemd.unit=rescue.target` to the `linux` line, **Ctrl-X**. Then:
```bash
systemctl get-default > /root/rescue-proof.txt
systemctl reboot
```
Editing at GRUB is one-shot — it does not change the default.

### T56 Transfer — 2 commands
```bash
scp /etc/redhat-release root@192.168.56.102:/root/from-node1.txt
rsync -a /etc/sysconfig/ root@192.168.56.102:/root/sysconfig-copy/
```
Trailing slash on the source copies *contents*; without it you get a nested directory.

### T57 bzip2 — **1 command**
```bash
tar cjpf /root/logs.tar.bz2 /var/log/messages
```
`j` = bzip2, `z` = gzip. Mixing them up is a classic.

### T58 Kernel args — 2 commands
```bash
grubby --update-kernel=ALL --args="quiet=0"
grubby --update-kernel=ALL --remove-args="quiet=0"
```

### T59 Repair permissions — 3 commands
```bash
chown root:admin /srv/broken/data.txt
chmod 664 /srv/broken/data.txt
chmod 1775 /srv/broken
```
Plus `usermod -aG admin harry` if harry isn't in the group.

### T60 Switching users — 2 commands
```bash
su - harry -c pwd
echo 'su - starts a login shell: loads the target user environment and cds to their home; su keeps the current environment' > /root/su-difference.txt
```

---

## The eight biggest keystroke wins

| Task | Instead of | Use | Saves |
|---|---|---|---|
| T04, T36 | mkdir + chgrp + chmod | `install -d -g G -m MODE` | 2 commands |
| T27 | lvextend + xfs_growfs | `lvextend -r` | 1 command |
| T43 | resize2fs + lvreduce | `lvreduce -r` | 1 command + ordering risk |
| T29 | four `chage` calls | `chage -M -W -I -d 0` | 3 commands |
| T15, T42 | pvcreate + vgcreate | `vgcreate` alone | 1 command |
| T08, T51 | interactive `fdisk` | `echo ',2G,S' \| sfdisk` | all the blind keystrokes |
| any fstab | blkid, then copy the UUID by hand | `$(blkid -s UUID -o value DEV)` | transcription errors |
| T40 | disable + stop | `systemctl mask --now` | 1 command |

## Where I deliberately did NOT shorten

- **T16** — `/.autorelabel` looks skippable. It is not.
- **T30** — `visudo -c` is one extra command that prevents locking yourself out.
- **T45** — `mount -a` before rebooting. Always.
- **T05** — `crontab -` overwrites; only safe on an empty crontab.
- **T49** — the `[Install]` section looks like boilerplate but `enable` fails silently without it.

Everything above still ends the same way:

```bash
bash /root/grade.sh -v && reboot
```
