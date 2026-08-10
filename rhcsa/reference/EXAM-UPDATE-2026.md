# 2026 Exam Update — from the Ozzoy Bits EX200 video (March 2026)

Source: *"RHCSA 9/10 Exam Prep: Real EX200 Questions & Step-by-Step Solutions — EX200 2026
Refresh and Updates"*, channel **Ozzoy Bits**, 3h 28m, transcript pulled and read in full.

Two findings here correct material I gave you earlier. Both are important.

---

# 🔴 FINDING 1 — `rd.break` does NOT work on RHEL 10

I taught you `rd.break`. **That is the RHEL 9 procedure.** RHEL 10 uses a different one.
Straight from the video: *"that works on RHEL 9 and not on RHEL 10."*

You must know **which version your exam is** — you choose it when you book — and use the
matching procedure.

## RHEL 9 procedure (what I taught — still correct for 9)

At the GRUB menu, press **e**. Find the `linux` line, go to after `quiet`, type:
```
rd.break
```
Press **Ctrl+X** (or **F10**) to boot.

```
mount -o remount,rw /sysroot
chroot /sysroot
passwd
```
Type the new password, `⏎`, type it again, `⏎`
```
touch /.autorelabel
exit
exit
```

## RHEL 10 procedure (NEW — I did not have this)

At the GRUB menu pick the **regular kernel** (avoid the rescue entry). Press **e**.
Go to the **end** of the `linux` line and append:
```
init=/bin/sh rw
```
Press **Ctrl+X** to boot.

```
passwd
```
Type the new password, `⏎`, type it again, `⏎`
```
touch /.autorelabel
exec /sbin/init 6
```

**If you forget the `rw`:** `passwd` fails with an *authentication token manipulation
error*. Recover with:
```
mount -o remount,rw /
```
then run `passwd` again.

**`touch /.autorelabel` is required in BOTH procedures.** The video is emphatic about this —
skip it and SELinux contexts go wrong and the box becomes unusable.

---

# 🔴 FINDING 2 — you must do this on **node2**, and failing it fails the exam

This is the single most valuable thing in the video, and I did not know it:

> *"People are failing the EX200 exam because they do this wrongly... you need to do the
> root password recovery process on node two. And if you fail to do that on node two, you
> just get the grades on node one... You can get 130 points or something like that if you
> do everything right in node one."*

**The mechanics:**
- The exam gives you **two machines** — node1 and node2 (names may differ)
- **node2's root password is unknown.** You recover it to get in at all
- Fail that, and you cannot do any node2 task
- A perfect node1 alone is worth roughly **130 of 300** — the pass mark is **210**

**So root password recovery is not one task worth a few points. It is the gate on roughly
half the exam.** Drill it until it's automatic, on the version you're sitting.

Also noted: the exam console has **reset / reboot / power-off controls**, so a machine you
wreck can be restored to fresh — at the cost of redoing everything on it.

---

# Other confirmations

**Containers are OUT.** The video agrees with what I found on Red Hat's site:
*"they don't include this in the exam objectives, and even the RHEL 10 objectives don't
even speak about containers."* He teaches it anyway as a bonus for RHEL 9 sitters.
→ Our **T26 is optional**. Do it for the skill, not for points.

**Flatpak is IN.** *"That was a new topic introduced on the exam objectives."*
→ Our **T46** covers it.

**VDO removed** from the objectives. We never covered it. No gap.

**Reboot mid-exam** — he advises rebooting partway through rather than only at the end, to
catch persistence bugs while you still have time to fix them. Matches our guidance.

---

# What the video does NOT cover

I mapped every RHCSA topic against the full transcript. These get **zero mentions**:

- Users and groups
- firewalld / firewall-cmd
- sudo / sudoers
- SSH key-based authentication
- journald / log analysis
- Hard and soft links
- sysctl

It is heavily weighted to containers (114 mentions), httpd (36), NFS/autofs (28), and
processes (26).

**Conclusion: the video is a supplement, not a syllabus.** It is strongest exactly where
our material was weakest (the RHEL 10 password procedure, the node2 insight) and silent on
seven objectives we already cover. Use both.

---

# Actions taken

1. RHEL 10 password recovery added to `Q1-Q111-LINEAR.md` (Q62), `DUMP-SOLUTIONS.md`
   (group Y) and `ANSWERS.md` (T16)
2. T26 (podman) marked optional
3. Practise password recovery on **both** lab nodes, not just node1
