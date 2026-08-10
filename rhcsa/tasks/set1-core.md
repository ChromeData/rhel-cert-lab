# RHCSA Practice Tasks — Set 1

Derived from the validexamdumps + examtopics EX200 questions, **answers stripped**,
reworded for RHEL 10 and de-duplicated. Fifteen tasks. Target: 2 hours.

## Rules

1. **Everything must survive a reboot.** Red Hat's own objectives page states:
   *"All configurations must persist after system reboot without manual intervention."*
   A service that is `active` but not `enabled` scores zero.
2. **You may use `man` and `/usr/share/doc`.** You get these on the real exam. Use them —
   looking things up fast is a scored skill in disguise. No browser, no notes, no AI.
3. Run everything on **node1** unless a task says otherwise.
4. When done: `sudo bash grade.sh`, then **reboot and grade again**. The second run is
   the one that counts.

Root password and setup are yours to establish during install.

---

## T01 — Networking

Configure the host-only interface with these static values:

- IPv4 `192.168.56.101/24`
- Gateway `192.168.56.1`
- DNS `192.168.56.1`
- Hostname `node1.domain40.example.com`

Add `10.0.0.5/24` as a **secondary** address on that same connection, in a way that does
not disturb the settings above.

## T02 — Users and groups

Create users `harry`, `natasha`, and `tom`.

- `harry` and `natasha` must have `admin` as a **supplementary** group.
- `tom`'s login shell must be non-interactive.

## T03 — User with a fixed UID

Create user `alex` with UID `1234` and password `alex111`.

## T04 — Collaborative directory

Create `/home/admins`, owned by group `admin`.

- Members of `admin` can read and write.
- All other users have **no** access.
- Files created inside it must automatically belong to the `admin` group.

## T05 — Scheduled task

Schedule `/bin/echo hello` to run at **14:23 every day**, as root.

## T06 — Find and collect

Find all **files** owned by `harry` anywhere on the system and copy them to `/opt/dir`,
preserving ownership and permissions.

## T07 — Filter a file

Write every line of `/etc/testfile` containing the string `abcde` to `/tmp/testfile`,
in the original order.

> Create the source first: `printf 'abcde one\nxxx\nabcde two\nyyy\nabcde three\n' > /etc/testfile`

## T08 — Swap

Add a **2 GiB** swap partition that activates automatically at boot. The existing swap
must remain in place and active. Use one of the spare disks (`/dev/sdb` or `/dev/sdc`).

Reference it in `/etc/fstab` by **UUID**, not device name.

## T09 — Web server

Install and configure Apache so it serves a page containing the string `RHCSA-OK` at
`http://192.168.56.101/`.

It must be reachable **from node2**, and must still work after a reboot.

## T10 — FTP server

Install and configure `vsftpd` for **anonymous download** from `/var/ftp/pub`.

Place a file named `README` in that directory. It must be retrievable from node2 and
survive a reboot.

## T11 — Firewall rule

Reject all traffic from the network `172.25.0.0/16`. Existing services must keep working.

Do this without flushing your other firewall configuration.

## T12 — Kernel

Ensure the **newest installed kernel** is the default boot target, without removing the
previous kernel.

## T13 — Software repository

Configure a `dnf` repository named `local` pointing at the attached installation media
(mount the ISO under `/mnt`), with GPG checking disabled. It must be usable by `dnf` and
persist across reboots.

## T14 — SELinux

SELinux must be in **enforcing** mode at boot, and the file served by Apache in T09 must
carry the correct SELinux type for web content.

## T15 — LVM

Using a spare disk, create:

- volume group `vgdata` with a 8 MiB physical extent size
- logical volume `lvdata` of **512 MiB**, formatted `xfs`
- mounted persistently at `/data`

---

## Grading

```bash
sudo bash grade.sh
```

Filter to one task while iterating:

```bash
sudo bash grade.sh -t 8
```

Then the real test:

```bash
sudo reboot
```

...and grade again. Anything that drops from PASS to FAIL is exactly the mistake every
one of those dump answers made.
