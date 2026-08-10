# RHCSA Practice Tasks — Set 4 (Gap Closure)

Sets 1–3 covered about 45 of Red Hat's ~60 published EX200 study points. **This set exists
purely to close the remaining 15.** It is the least "fun" set and the most important —
these are the objectives you'd otherwise walk into the exam never having touched.

Mapped bullet-for-bullet against the official objective list at
<https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>

Target: 90 minutes. Run on **node1** unless stated.

---

## T46 — Flatpak *(Manage Software)*

> New in the RHEL 10 objectives. Practise it even though this lab runs Rocky 9 — the
> commands are identical.

- Install Flatpak support
- Add the Flathub remote
- Install any Flatpak application
- List installed Flatpaks, then remove the one you installed

## T47 — SSH key-based authentication *(Manage Security)*

- As `harry` on **node1**, generate an SSH keypair
- Deploy the public key so `harry` can log into **node2** without a password
- Then disable **password** authentication on node2's sshd entirely

Verify both: key login works, password login is refused.

## T48 — SELinux booleans *(Manage Security)*

Allow `httpd` to make outbound network connections, persistently, using a boolean —
**not** by disabling SELinux.

Then list every currently-enabled boolean whose name contains `httpd` and write them to
`/root/httpd-booleans.txt`.

## T49 — systemd timer unit *(Deploy, Configure, Maintain)*

Replace a cron job with a **systemd timer**:

- Service unit `hello.service` that runs `/bin/echo hello`
- Timer unit `hello.timer` that triggers it **every 10 minutes**
- Enabled and active, surviving reboot

Do **not** use cron for this one.

## T50 — `at` one-time job *(Deploy, Configure, Maintain)*

Schedule a **one-time** job using `at` that writes the date into `/root/at-ran.txt`,
scheduled for `23:55` today. Confirm it's queued.

Make sure the `atd` service is enabled.

## T51 — VFAT filesystem *(Create and Configure File Systems)*

On a spare disk, create a **1 GiB** partition formatted **VFAT**, mounted persistently at
`/mnt/usbsim` by **UUID**.

> VFAT is explicitly named in the objectives alongside ext4 and XFS. Most people only
> practise the latter two.

## T52 — IPv6 *(Manage Basic Networking)*

Add the static IPv6 address `fd00:56::101/64` to the host-only connection, persistently,
without disturbing IPv4.

Verify with `ping6` to yourself.

## T53 — Hostname resolution via /etc/hosts *(Manage Basic Networking)*

Make `node2.lab.local` and `db.lab.local` both resolve to `192.168.56.102` locally,
without DNS. Verify with `getent hosts`.

## T54 — Process management *(Operate Running Systems)*

1. Start a CPU-burning process in the background:
   `nohup bash -c 'while :; do :; done' &`
2. Identify it by highest CPU usage and record its PID in `/root/hog.txt`
3. Renice it to priority `19`
4. Then kill it

Leave `/root/hog.txt` in place as evidence.

## T55 — Boot into a target manually *(Operate Running Systems)*

Reboot and interrupt GRUB to boot **once** into `rescue.target` — without changing the
default target.

Once there, create the file `/root/rescue-proof.txt` containing the output of
`systemctl get-default`, then boot normally again.

## T56 — Secure file transfer *(Operate Running Systems)*

Copy `/etc/redhat-release` from **node1** to **node2** at `/root/from-node1.txt` using
`scp`, then use `rsync` to sync the whole of `/etc/sysconfig` from node1 to node2 at
`/root/sysconfig-copy/`, preserving permissions.

## T57 — bzip2 archive *(Understand and Use Essential Tools)*

Create `/root/logs.tar.bz2` containing `/var/log/messages` (or `/var/log/secure` if that
doesn't exist), compressed with **bzip2** specifically — not gzip.

Verify the compression type with `file`.

## T58 — Kernel arguments *(Deploy, Configure, Maintain — bootloader)*

Add the kernel boot parameter `quiet=0` to **all** installed kernels persistently, using
`grubby`. Verify it's present in the boot entries.

Then remove it again, cleanly.

## T59 — Diagnose and fix permissions *(Create and Configure File Systems)*

Break it, then fix it:

```bash
mkdir -p /srv/broken && echo secret > /srv/broken/data.txt
chmod 000 /srv/broken /srv/broken/data.txt
chown nobody:nobody /srv/broken/data.txt
```

Now make it so that:
- `harry` can read **and** write `data.txt`
- The file is owned by `root:admin`
- `/srv/broken` is traversable by everyone but writable only by `admin`

## T60 — Switching users *(Understand and Use Essential Tools)*

- Verify you can switch to `harry` with a full login shell and land in his home directory
- Show the difference between `su harry` and `su - harry` — write a one-line explanation
  to `/root/su-difference.txt`
- Confirm `dbadmin` (Set 3) can escalate via `sudo -i`

---

## Coverage after Set 4

With Sets 1–4 (**60 tasks**) every published EX200 study point has at least one
corresponding practice task.

That is coverage, not mastery. Coverage means you've *touched* everything once. Mastery is
passes 3 and 4 with the snapshot, timed, no notes.

## Grading

```bash
sudo bash grade4.sh -v
```
