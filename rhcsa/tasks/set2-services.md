# RHCSA Practice Tasks — Set 2

Written from Red Hat's published EX200 objectives, **not** from exam dumps. Covers the
areas Set 1 misses entirely: shell scripting, ACLs, NFS/autofs, log analysis, tuned,
containers, and root password recovery.

Same rules as Set 1: everything must survive a reboot, `man` is allowed, grade twice.

Target: 2 hours. Run on **node1** unless stated.

---

## T16 — Recover a lost root password

Reboot node1 and gain root access **without** knowing the password. Set it to `Rhcsa!2026`.

Then do the same on **node2**.

> **This gates roughly half the real exam.** On EX200 node2's root password is not given to
> you — fail the recovery and you cannot attempt any node2 task. A perfect node1 alone is
> about 130 of 300 points, and you need 210.
>
> **Two procedures — know which version you booked:**
> - **RHEL 9:** GRUB → `e` → add `rd.break` after `quiet` → Ctrl+X
> - **RHEL 10:** GRUB → `e` → append ` init=/bin/sh rw` to the end of the `linux` line → Ctrl+X
>
> `rd.break` does **not** work on RHEL 10. See `EXAM-UPDATE-2026.md` for both in full.

## T17 — Shell script: argument handling

Write `/usr/local/bin/reportuser` so that:

- With **no** argument, it prints `Usage: reportuser <username>` and exits with status `1`
- With a username that **exists**, it prints that user's UID, primary group, and shell
- With a username that **does not exist**, it prints `no such user: <name>` and exits `2`

Must be executable by everyone.

## T18 — Shell script: loop over input

Write `/usr/local/bin/sizes` that takes one directory as an argument and, for every
**regular file** directly inside it, prints `<filename> <size-in-bytes>` — one per line,
sorted largest first.

If the argument isn't a directory, exit `1` with an error on stderr.

## T19 — ACLs

Create `/srv/shared/report.txt`.

- Owner `root`, group `admin`
- User `harry` gets **read-write** via ACL, regardless of group membership
- User `tom` gets **no access at all** via ACL
- Everyone else: read only

The ACLs must survive a reboot.

## T20 — NFS export

Export `/srv/nfsshare` from **node1** read-write, restricted to `192.168.56.0/24` only.

Create a file inside it so there's something to see.

## T21 — NFS mount (on node2)

On **node2**, mount node1's `/srv/nfsshare` at `/mnt/remote` persistently.

Verify you can read the file from T20.

## T22 — autofs

On **node2**, configure `autofs` so that `/net/shared` automatically mounts node1's
`/srv/nfsshare` on access, and unmounts when idle.

Disable the persistent mount from T21 first — they'll conflict.

## T23 — Log analysis

Find every failed SSH login attempt on node1 since the last boot and write just those
lines to `/root/failed-logins.txt`.

Then make the system journal **persistent** across reboots.

## T24 — Time services

Configure node1 to sync time from `192.168.56.1`, set the timezone to `America/New_York`,
and confirm NTP synchronisation is enabled.

## T25 — tuned

Set the active `tuned` profile to `virtual-guest` and make it persist.

Report which profile `tuned` would recommend for this machine.

## T26 — Container: run and persist

Using `podman` as a **rootless** user (`harry`):

- Pull the `registry.access.redhat.com/ubi9/ubi` image
- Run a container named `webtest` that stays running
- Configure it to **start automatically at boot** as a systemd user service

> Note: verify `podman` is in your exam version's objectives — container tasks were part
> of RHEL 8/9 RHCSA. Practise it regardless; it's useful.

## T27 — Storage: extend a logical volume

Grow `vgdata`/`lvdata` (from Set 1 T15) to **1 GiB**, including the filesystem, **without
unmounting it**.

If you don't have Set 1's LVM in place, build it first.

## T28 — Storage: stratis or VDO alternative

Create a second logical volume `lvlogs` (256 MiB, `ext4`) in `vgdata`, mounted at
`/var/log/archive` persistently, with the `noexec` mount option.

## T29 — Users: password aging

For user `natasha`:

- Password must expire after **60 days**
- Warn **10 days** before expiry
- Account must be locked after **7 days** of password inactivity
- Force a password change at next login

## T30 — sudo

Configure so that members of the `admin` group can run **only** `/usr/bin/systemctl` and
`/usr/bin/journalctl` as root, without being prompted for a password.

Nothing else. Verify as `harry`.

---

## Grading

Set 2 tasks are graded by `grade2.sh`:

```bash
sudo bash grade2.sh -v
```

Then reboot and run it again.
