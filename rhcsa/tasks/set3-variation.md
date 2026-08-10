# RHCSA Practice Tasks — Set 3

**Different values, same skills.** Sets 1 and 2 taught you the commands; this set stops
you from memorising the *answers*. Every username, size, IP, and path here is different
on purpose — if you can do Set 3 cold, you actually know it.

Also covers the last of the RHEL 9 objectives: archives, links, umask, sysctl, systemd
targets, and boot troubleshooting.

Same rules: must survive a reboot, `man` allowed, grade twice.

Target: 2 hours. **Restore the `clean-install` snapshot before starting.**

---

## T31 — Networking (again, new values)

Set the host-only interface to:

- IPv4 `192.168.56.150/24`
- Gateway `192.168.56.1`
- DNS `8.8.8.8` **and** `192.168.56.1` (in that order)
- Hostname `server3.lab.example.com`

## T32 — Users (again, new values)

- `dbadmin` — UID `2500`, primary group `dba` (create it), shell `/bin/bash`
- `svcbackup` — system account, no home directory, shell `/sbin/nologin`
- `intern` — account **expires** on `2027-01-01`

Password for `dbadmin` and `intern`: `Passw0rd!23`

## T33 — Archives

Create `/root/etcbackup.tar.gz` containing `/etc/hosts`, `/etc/fstab`, and `/etc/passwd`,
preserving permissions.

Then extract it to `/tmp/restore/` so the files land as `/tmp/restore/etc/hosts` etc.

## T34 — Links

In `/opt/links`:

- A **hard** link named `hard-fstab` pointing at `/etc/fstab`
- A **symbolic** link named `soft-fstab` pointing at `/etc/fstab`

Then explain (in `/opt/links/NOTES.txt`, one line) what happens to each if `/etc/fstab`
is deleted.

## T35 — umask

Set the system-wide default `umask` to `027` for all **interactive login shells**, so new
files are created `640` and new directories `750`.

Must apply to new logins after a reboot.

## T36 — Permissions puzzle

Create `/srv/dropbox` where:

- Any user can create files
- Users can **only delete their own** files (not each other's)
- The directory is group-owned by `dba`

## T37 — Find with criteria

Find every file under `/etc` larger than **100 KB** and modified in the last **30 days**,
and write their full paths to `/root/bigrecent.txt`, one per line.

## T38 — sysctl

Make the kernel setting `net.ipv4.ip_forward` equal to `1`, persistently, using a drop-in
file (not by editing `/etc/sysctl.conf`).

## T39 — systemd default target

Set the system's default boot target to `multi-user.target` and confirm it.

Then report which target the system is in **right now**.

## T40 — Service masking

Install `httpd` but ensure it can **never** be started accidentally — mask it. Then prove
`systemctl start httpd` fails.

## T41 — Swap (again, new size)

Add a **1 GiB** swap file (not a partition) at `/swapfile`, active at boot, without
disturbing existing swap.

> Note the difference from Set 1 — this is a *file*, not a partition. The fstab syntax and
> permissions differ.

## T42 — LVM (again, new values)

- Volume group `vgapp`, PE size `16M`
- Logical volume `lvapp`, `768 MiB`, `ext4`
- Mounted at `/srv/app`, persistently, with the `nodev` option

## T43 — LVM: reduce and remove

Shrink `lvapp` to `512 MiB` safely (filesystem first!), then create a snapshot LV named
`lvapp-snap` of `128 MiB`.

> `ext4` can shrink; `xfs` cannot. That distinction is examinable.

## T44 — SELinux port label

Configure `httpd` to listen on port `8088` **with SELinux enforcing**. Unmask it first.

You will need `semanage port`. Confirm with `curl http://localhost:8088/`.

## T45 — Boot troubleshooting

Break it, then fix it:

1. Add a deliberately bad line to `/etc/fstab` referencing a non-existent UUID
2. Reboot — the system will drop to emergency mode
3. Recover it without reinstalling

Then remove the bad line and confirm a clean boot.

> This is the highest-value 20 minutes of practice in the entire lab. A bad fstab entry is
> the classic way people brick their exam machine with 40 minutes left.

---

## Grading

```bash
sudo bash grade3.sh -v
```

---

## How to actually use these sets

You do **not** need 100 unique tasks. You need these 45 done until they're automatic.

The snapshot makes each set infinitely repeatable:

```bash
# from Windows, roll back to a pristine box in ~2 seconds
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' snapshot rhcsa-node1 restore clean-install
```

A realistic drill schedule:

| Pass | Goal |
|---|---|
| 1st | Use `ANSWERS.md` freely. You're learning where things live. |
| 2nd | `man` only. Slow is fine. |
| 3rd | Timed — 2 hours, no help. Score it. |
| 4th+ | Repeat whichever set you scored worst on. |

By pass 4 you'll be typing `firewall-cmd --permanent --add-service=http && firewall-cmd --reload` without thinking. That reflex is what the exam actually measures.
