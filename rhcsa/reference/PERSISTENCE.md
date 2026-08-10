# What makes each task survive a reboot

## The mental model

**Linux has no "save" button.** Either a command wrote to a config file — in which case it
already persisted, nothing more to do — or it only changed memory, and it dies at reboot.

There is no third state. Every task below is just: *did I write to disk or not?*

---

## The runtime-only commands that lose your work

If you used one of these and nothing else, that task scores **zero** after reboot:

| You typed | Dies at reboot | Do this instead |
|---|---|---|
| `ip addr add` | yes | `nmcli con mod` |
| `hostname NAME` | yes | `hostnamectl set-hostname` |
| `setenforce 1` | yes | also edit `/etc/selinux/config` |
| `setsebool X on` | yes | `setsebool -P X on` |
| `sysctl -w` | yes | file in `/etc/sysctl.d/` |
| `swapon /dev/X` | yes | also add to `/etc/fstab` |
| `mount /dev/X /mnt` | yes | also add to `/etc/fstab` |
| `systemctl start X` | yes | `systemctl enable --now X` |
| `firewall-cmd --add-service=X` | yes | add `--permanent`, then `--reload` |
| `exportfs -o ...` | yes | write `/etc/exports` |

Nine of those ten are the entire reason people fail a performance-based exam.

---

## Per task — what actually persists it

### Exam 1

| # | Persisted by | Silent killer |
|---|---|---|
| T01 | `nmcli con mod` writes the profile; `hostnamectl` writes `/etc/hostname` | using `ip addr add` |
| T02 | `useradd` writes `/etc/passwd` | none — always persistent |
| T03 | `useradd` + `chpasswd` write `/etc/shadow` | none |
| T04 | `install -d` / `chmod` write the inode | none |
| T05 | `crontab -` writes `/var/spool/cron/root` | **crond not enabled** |
| T06 | `cp` writes real files | none |
| T07 | redirect writes a real file | none |
| T08 | **`/etc/fstab` line** | mkswap + swapon but no fstab entry |
| T09 | `systemctl enable`, `firewall-cmd --permanent` | `start` without `enable`; firewall without `--permanent` |
| T10 | same as T09 | same |
| T11 | `--permanent` **and** `--reload` | forgetting either one |
| T12 | grubby writes the BLS entries | none |
| T13 | repo file **and** the `/mnt/dvd` fstab line | repo persists but the mount doesn't → repo breaks |
| T14 | `/etc/selinux/config` | `setenforce 1` alone |
| T15 | **`/etc/fstab` line** | mkfs + mount but no fstab entry |

### Exam 2

| # | Persisted by | Silent killer |
|---|---|---|
| T16 | `passwd` in chroot | **missing `touch /.autorelabel`** → cannot log in |
| T17/T18 | the script file itself | forgetting `chmod +x` |
| T19 | ACLs live in the filesystem | none |
| T20 | `/etc/exports` + `enable` + `--permanent` | `exportfs` alone |
| T21 | `/etc/fstab` | manual `mount` only |
| T22 | map files + `enable` | none |
| T23 | `/var/log/journal` existing | creating it but not restarting journald |
| T24 | `/etc/chrony.conf` + `enable` | none |
| T25 | `tuned-adm profile` writes its own state | none |
| T26 | **`loginctl enable-linger harry`** | without linger the container dies at logout |
| T27 | LVM metadata is on disk | none |
| T28 | `/etc/fstab` with `noexec` | mounting with noexec but omitting it from fstab |
| T29 | `chage` writes `/etc/shadow` | none |
| T30 | `/etc/sudoers.d/` file | syntax error → run `visudo -c` |

### Exam 3

| # | Persisted by | Silent killer |
|---|---|---|
| T31 | `nmcli con mod` | `ip addr add` |
| T32 | `useradd` | none |
| T33 | the archive file | none |
| T34 | links are filesystem objects | none |
| T35 | `/etc/profile.d/umask.sh` | `umask 027` typed at a prompt |
| T36 | inode mode | none |
| T37 | the output file | none |
| T38 | `/etc/sysctl.d/*.conf` | `sysctl -w` alone |
| T39 | `set-default` writes a symlink | none |
| T40 | `mask` writes a symlink | `disable` instead of `mask` |
| T41 | `/etc/fstab` | ⚠ swap **file** goes in by **path**, not UUID |
| T42 | `/etc/fstab` | none |
| T43 | LVM metadata | shrinking the LV before the filesystem = data loss |
| T44 | `semanage port -a` is permanent; httpd.conf on disk | `--permanent` missing on firewall |
| T45 | removing the bad line | ⚠ **`mount -a` before rebooting**, every time |

### Exam 4

| # | Persisted by | Silent killer |
|---|---|---|
| T46 | flatpak remote config | none |
| T47 | `authorized_keys` + sshd drop-in | editing sshd but not reloading |
| T48 | **`setsebool -P`** | omitting `-P` |
| T49 | unit files + `enable` | ⚠ missing `[Install] WantedBy=` → enable silently no-ops |
| T50 | at job spool | **atd not enabled** |
| T51 | `/etc/fstab` | none |
| T52 | `nmcli con mod` | `ip -6 addr add` |
| T53 | `/etc/hosts` | none |
| T54 | the output file | none |
| T55 | nothing should persist — GRUB edit is one-shot by design | accidentally running `set-default` |
| T56 | the copied files | none |
| T57 | the archive | `z` instead of `j` gives gzip |
| T58 | grubby writes boot entries | none |
| T59 | inode ownership/mode | none |
| T60 | the notes file | none |

---

## The three that actually brick the machine

Everything else costs you one task. These cost you the exam.

**1. fstab typo → emergency mode.** After *any* fstab edit:
```bash
mount -a
```
If that returns nothing, you are safe to reboot. If it errors, fix it now — not after.

**2. Root password recovery without `/.autorelabel`.** SELinux relabels are what let you
log in afterwards. Skip it and the box is unusable.

**3. Shrinking a filesystem in the wrong order.** `lvreduce -r` does it correctly. Doing
`lvreduce` before shrinking the filesystem destroys data. And **xfs cannot shrink at all** —
only ext4.

---

## Your loop, every time

```bash
mount -a
```
```bash
bash /root/grade.sh -v
```
```bash
reboot
```
```bash
bash /root/grade.sh -v
```

Anything that drops from PASS to FAIL between those two runs is a persistence bug —
find it in the table above.
