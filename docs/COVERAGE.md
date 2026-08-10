# Objective Coverage Map

Every published EX200 study point → the task that drills it. Source:
<https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam>

Verified 2026-08-08. If Red Hat revises the objectives, re-check this map.

---

## 1. Understand and use essential tools

| Objective | Task |
|---|---|
| Shell prompt, correct syntax | all |
| Input/output redirection | T07, T37 |
| grep and regular expressions | T07, T37 |
| Access remote systems using SSH | T47, T56 |
| Log in and switch users in multi-user targets | T60 |
| Archive/compress with tar, gzip, bzip2 | T33 (gzip), T57 (bzip2) |
| Create and edit text files | T34, T60 |
| Create, delete, copy, move files/dirs | T06, T33 |
| Create hard and soft links | T34 |
| Standard ugo/rwx permissions | T04, T36, T59 |
| Locate and use system documentation | practised throughout |

## 2. Manage software

| Objective | Task |
|---|---|
| Configure access to RPM repositories | T13 |
| Install and remove RPM packages | T09, T10, T40 |
| Configure access to Flatpak repositories | T46 |
| Install and remove Flatpak packages | T46 |

## 3. Create simple shell scripts

| Objective | Task |
|---|---|
| Conditionals (if, test, []) | T17 |
| Looping constructs | T18 |
| Process script inputs ($1, $2) | T17, T18 |
| Process output of commands in a script | T18 |

## 4. Operate running systems

| Objective | Task |
|---|---|
| Boot, reboot, shut down normally | throughout |
| Boot into different targets manually | T55 |
| Interrupt boot to gain access | T16 |
| Identify CPU/memory hogs and kill | T54 |
| Adjust process scheduling | T54 |
| Manage tuning profiles | T25 |
| Locate and interpret logs and journals | T23 |
| Preserve system journals | T23 |
| Start/stop/check network services | T09, T10, T20 |
| Securely transfer files between systems | T56 |

## 5. Configure local storage

| Objective | Task |
|---|---|
| List/create/delete partitions on GPT | T08, T51 |
| Create and remove physical volumes | T15, T42 |
| Assign PVs to volume groups | T15, T42 |
| Create and delete logical volumes | T15, T42, T43 |
| Mount at boot by UUID or label | T08, T15, T42, T51 |
| Add partitions/LVs/swap non-destructively | T08, T41, T27 |

## 6. Create and configure file systems

| Objective | Task |
|---|---|
| VFAT, ext4, XFS | T51 (vfat), T28/T42 (ext4), T15 (xfs) |
| Mount/unmount NFS | T21 |
| Configure autofs | T22 |
| Extend existing logical volumes | T27 |
| Diagnose and correct permission problems | T59 |

## 7. Deploy, configure, and maintain systems

| Objective | Task |
|---|---|
| Schedule with at, cron, systemd timers | T50 (at), T05 (cron), T49 (timer) |
| Services start automatically at boot | T09, T10, T24, T49 |
| Boot into a specific target automatically | T39 |
| Configure time service clients | T24 |
| Install/update from repo or local filesystem | T13 |
| Modify the system bootloader | T12, T58 |

## 8. Manage basic networking

| Objective | Task |
|---|---|
| Configure IPv4 addresses | T01, T31 |
| Configure IPv6 addresses | T52 |
| Configure hostname resolution | T01, T31 (DNS), T53 (/etc/hosts) |
| Network services start at boot | T09, T10, T20 |
| Restrict network access with firewalld | T11 |

## 9. Manage users and groups

| Objective | Task |
|---|---|
| Create, delete, modify local users | T02, T03, T32 |
| Change passwords, password aging | T03, T29, T32 |
| Create, delete, modify groups/membership | T02, T32 |
| Configure privileged access | T30, T60 |

## 10. Manage security

| Objective | Task |
|---|---|
| Firewall settings with firewall-cmd | T09, T10, T11 |
| Manage default file permissions | T35 (umask) |
| Key-based SSH authentication | T47 |
| SELinux enforcing/permissive modes | T14 |
| List and identify SELinux contexts | T14, T44 |
| Restore default file contexts | T14 |
| Manage SELinux port labels | T44 |
| SELinux booleans | T48 |

---

## Honest caveats

**Coverage ≠ mastery.** Every bullet has at least one task. Touching something once is not
the same as being able to do it in four minutes under pressure.

**The lab runs Rocky 9; the exam is RHEL 10.** Near-identical at this level. Two known
differences worth reading up on separately:
- Flatpak objectives are new in RHEL 10 (T46 still works on 9 — same commands)
- RHEL 10 defaults some things differently; check `man` on exam day, not memory

**Objectives change.** Red Hat revises them per release. Re-read the official page before
you book the exam — do not trust this file or any dump to still be current.

**No practice lab predicts the real thing perfectly.** This gets you fluent in the
mechanics. The exam still throws wording you haven't seen.
