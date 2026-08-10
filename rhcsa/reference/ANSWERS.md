# Answer Key — Set 1

**Try the task first.** Reading this instead of attempting it is exactly how people fail a
performance-based exam — recognising a correct command is a completely different skill
from producing it under time pressure.

Every command here is RHEL 10 / Rocky 10 correct and verified against the grader.
Interface names are examples — always confirm with `nmcli device status`.

---

## T01 — Networking

```bash
nmcli device status                      # find the host-only device, e.g. enp0s8
nmcli con add con-name static ifname enp0s8 type ethernet \
  ipv4.addresses 192.168.56.101/24 ipv4.gateway 192.168.56.1 \
  ipv4.dns 192.168.56.1 ipv4.method manual connection.autoconnect yes
nmcli con mod static +ipv4.addresses 10.0.0.5/24
nmcli con up static
hostnamectl set-hostname node1.domain40.example.com
```

**Gotcha:** the `+` in `+ipv4.addresses` *adds* an address. Without it you **replace** the
primary and lose the first one. That's what "does not compromise your existing settings"
is testing.

## T02 — Users and groups

```bash
groupadd admin
useradd -G admin harry
useradd -G admin natasha
useradd -s /sbin/nologin tom
```

**Gotcha:** `-G` is supplementary, `-g` is primary. `useradd -G admin` **fails** if the
group doesn't exist — create it first. Verify with `id harry`.

## T03 — User with fixed UID

```bash
useradd -u 1234 alex
echo 'alex:alex111' | chpasswd
```

`chpasswd` is more reliable in scripts than `passwd --stdin`.

## T04 — Collaborative directory

```bash
mkdir /home/admins
chgrp admin /home/admins
chmod 2770 /home/admins
```

**Gotcha:** `2770` = setgid (2) + owner rwx + group rwx + other none. `2750` fails — the
group needs **write**. The setgid bit is what makes new files inherit the `admin` group.

## T05 — Scheduled task

```bash
systemctl enable --now crond
crontab -e          # then add the line below
```
```
23 14 * * * /bin/echo hello
```

**Gotcha:** cron field order is minute-first. 14:23 is `23 14`, not `14 23`.

## T06 — Find and collect

```bash
mkdir -p /opt/dir
find / -type f -user harry -exec cp -a {} /opt/dir/ \;
```

**Gotcha:** without `-type f` you match `/proc` entries if harry has running processes,
and `cp -r` on those can hang. `-a` preserves ownership and permissions.

## T07 — Filter a file

```bash
grep 'abcde' /etc/testfile > /tmp/testfile
```

That's the whole answer. If you wrote a `while read` loop, you overthought it.

## T08 — Swap

```bash
lsblk                                    # confirm the spare disk, e.g. /dev/sdb
fdisk /dev/sdb                           # n, accept defaults, +2G, t, 19 (Linux swap), w
partprobe /dev/sdb
mkswap /dev/sdb1
blkid /dev/sdb1                          # copy the UUID
vim /etc/fstab                           # UUID=xxxx none swap defaults 0 0
systemctl daemon-reload
swapon -a
swapon --show                            # verify BOTH swaps active
```

**Gotcha:** order matters — `mkswap` → **fstab entry** → `swapon -a`. Running `swapon -a`
before writing fstab does nothing. On GPT the swap type code is `19`, not `82`.

## T09 — Web server

```bash
dnf install -y httpd
echo 'RHCSA-OK' > /var/www/html/index.html
restorecon -Rv /var/www/html
systemctl enable --now httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

**Gotcha:** `--permanent` then `--reload`, or the rule dies on reboot. Test from **node2**,
not localhost — localhost bypasses the firewall entirely and proves nothing.

## T10 — FTP server

```bash
dnf install -y vsftpd
echo 'hello' > /var/ftp/pub/README
restorecon -Rv /var/ftp
systemctl enable --now vsftpd
firewall-cmd --permanent --add-service=ftp
firewall-cmd --reload
```

`anonymous_enable=YES` is already the default in Rocky/RHEL's `vsftpd.conf`.

## T11 — Firewall rule

```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.25.0.0/16" reject'
firewall-cmd --reload
firewall-cmd --list-rich-rules
```

**Gotcha:** never `iptables -F` — it wipes every other rule you've been graded on. RHEL 10
uses firewalld over nftables; raw `iptables` is a compatibility shim.

## T12 — Kernel

```bash
grubby --default-kernel
rpm -q kernel                            # newest should already be default
grubby --set-default /boot/vmlinuz-<newest>   # only if it isn't
```

**Gotcha:** `dnf install kernel` (not `update`) keeps the old one — kernel is in
`installonlypkgs`. `/boot/grub/grub.conf` and `default=0` haven't existed since RHEL 6.

## T13 — Repository

```bash
mkdir -p /mnt/dvd
echo '/dev/sr0 /mnt/dvd iso9660 defaults,ro 0 0' >> /etc/fstab
systemctl daemon-reload
mount -a
cat > /etc/yum.repos.d/local.repo <<'EOF'
[local]
name=local
baseurl=file:///mnt/dvd/BaseOS
enabled=1
gpgcheck=0
EOF
dnf repolist
```

**Gotcha:** the **mount must be in fstab too**, or the repo breaks on reboot. Rocky/RHEL
DVDs have two repo dirs — `BaseOS` and `AppStream`. Add both if you want full coverage.

## T14 — SELinux

```bash
getenforce
setenforce 1
vim /etc/selinux/config                  # SELINUX=enforcing
restorecon -Rv /var/www/html
ls -Z /var/www/html/index.html           # want httpd_sys_content_t
```

**Gotcha:** `setenforce 1` is runtime only. Without editing `/etc/selinux/config` it
reverts on reboot. Files created *inside* `/var/www/html` inherit the right label; files
`mv`d in from a home directory keep `user_home_t` and cause a 403.

## T15 — LVM

```bash
lsblk
pvcreate /dev/sdc
vgcreate -s 8M vgdata /dev/sdc
lvcreate -L 512M -n lvdata vgdata
mkfs.xfs /dev/vgdata/lvdata
mkdir /data
blkid /dev/vgdata/lvdata
vim /etc/fstab                           # UUID=xxxx /data xfs defaults 0 0
systemctl daemon-reload
mount -a
df -h /data
```

**Gotcha:** `-s 8M` sets the physical extent size and must be on `vgcreate` — you cannot
change it later without recreating the VG. Always `mount -a` before rebooting: a typo in
fstab drops an unbootable system into emergency mode, and *that* is how people fail.

---

## The one habit worth more than this whole page

```bash
sudo bash grade.sh -v && sudo reboot
```

...then grade again. Every single wrong answer in those exam dumps would have passed a
pre-reboot check and failed the post-reboot one.
