# RHCSA → RHCE Study Plan

One path, in order. Each phase says what to do, how long, how many reps, and **how you
know you're done**. Don't advance on time — advance on the gate.

**Total: ~130 hours.** RHCSA at hour 76, RHCE at hour 130.

A "rep" = do the task start to finish, from a clean snapshot, without looking at notes.

---

## How to use this

Every phase runs the same loop:

1. Read the sequence on `CARD.md`
2. Do a task from the exam page
3. `check <n>` or `grade<N>.sh -v`
4. **Reboot, verify again**
5. Restore the snapshot, do it again with different values

```
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' snapshot rhcsa-node1 restore clean-install
```

Two seconds, clean box, go again.

---

# PART 1 — RHCSA (76 hours)

Ordered by **leverage**: what earns the most points and unlocks the most other tasks first.

### Phase 0 — Orientation · 3 hours · no reps
Boot the lab. Log into both nodes. Learn `lsblk`, `df -h`, `systemctl status`, `man -k`.
Read `CARD.md` once.

**Gate:** you can move around the filesystem and read a service's status without help.

---

### Phase 1 — Storage · 14 hours · **8 reps** 🔴 highest leverage
Partitions, swap, LVM create, LVM extend, LVM shrink, fstab by UUID, VFAT/ext4/xfs.

Why first: it's the biggest block of exam points, other tasks depend on disks existing,
and a fstab mistake here can cost you the whole machine — you want that reflex early.

**Gate:** you can build a VG + LV + filesystem + fstab entry from memory, reboot, and it
survives. Three times in a row. No notes.

---

### Phase 2 — Services & firewall · 10 hours · **6 reps**
httpd, vsftpd, nfs-server. `enable --now`. `firewall-cmd --permanent` + `--reload`.
Test from node2, never from localhost.

Why second: same four beats every time, and it's the other big point block.

**Gate:** you install, enable and open a service, then prove it from node2, in under 4
minutes.

---

### Phase 3 — Users, groups, permissions · 8 hours · **5 reps**
useradd/groupadd, supplementary vs primary, password aging, setgid, sticky, ACLs, sudo.

**Gate:** you can read "members of X can read and write, nobody else" and produce the
right mode without thinking.

---

### Phase 4 — SELinux · 7 hours · **5 reps**
Enforcing at boot, file contexts, `restorecon`, port labels with `semanage`, booleans
with `setsebool -P`.

Why here: it silently breaks the services you just learned, so it lands better after
Phase 2.

**Gate:** given a 403 on a web page, you find and fix the context in under 2 minutes.

---

### Phase 5 — Boot, kernel, recovery · 8 hours · **6 reps** 🔴 gates half the real exam
Root password recovery on **both** RHEL 9 and RHEL 10 procedures. GRUB editing. `grubby`.
Boot targets. fstab recovery from emergency mode.

Why it matters this much: on the real exam the second machine's root password is not
given to you. Fail this and every task on that machine is unreachable.

**Gate:** you recover a root password cold, both procedures, without notes. Then break
fstab deliberately and recover from emergency mode.

---

### Phase 6 — Networking · 6 hours · **4 reps**
`nmcli con mod`, secondary addresses, IPv6, hostname, `/etc/hosts`, DNS order.

**Gate:** static IP + gateway + DNS + hostname, persistent through a reboot, in 3 minutes.

---

### Phase 7 — Scheduling, logs, time, tuning · 6 hours · **4 reps**
cron, `at`, systemd timers, journald persistence, chrony, `tuned`.

**Gate:** you can write a cron line and a systemd timer for the same job and explain when
you'd use each.

---

### Phase 8 — Shell scripting · 8 hours · **5 reps**
`$1`, `if`/`test`, `for`, exit codes, reading command output.

**Gate:** you write a script that takes an argument, validates it, and exits with the
right code — from a blank file, no template.

---

### Phase 9 — Break/fix · 6 hours · **10 faults**
```
break-fix -l 3
```
No hints. Diagnose, fix, `--check`, reboot, `--check` again.

Why here: it's the first phase that mixes everything, and it's the closest thing to the
actual job.

**Gate:** 8 of 10 faults diagnosed without `--reveal`.

---

### Phase 10 — Full timed exams · 8 hours · **4 full runs**
34 tasks, 180 minutes, clean snapshot, no notes. Grade, reboot, grade again.

**Gate: 3 consecutive runs above 85%.** Not 70 — you want margin for exam nerves.

> ### ✅ RHCSA READY — hour 76

---

# PART 2 — RHCE / EX294 (54 hours)

All Ansible. Do not start until the RHCSA gate is passed — every playbook you write
automates something from Part 1, so you need to know it by hand first.

### Phase 11 — Ansible fundamentals · 10 hours · **5 reps**
Install, `ansible.cfg`, inventory, ad-hoc commands, modules, idempotency.

**Gate:** you explain why running a playbook twice should report `changed=0`, and you can
make a task that doesn't.

---

### Phase 12 — Playbooks · 14 hours · **8 reps**
Tasks, variables, facts, loops, conditionals, handlers, `register`, error handling.

Rewrite Part 1 as playbooks: the storage task, the httpd task, the user task. Same
outcome, written down instead of typed.

**Gate:** you convert any RHCSA task into a working idempotent playbook in under 10
minutes.

---

### Phase 13 — Roles, templates, vault · 12 hours · **6 reps**
Role structure, `ansible-galaxy init`, Jinja2 templates, `vault`, `when`/`tags`.

**Gate:** you build a role from scratch that configures a service on several hosts, with
a templated config file and an encrypted variable.

---

### Phase 14 — System roles & scale · 8 hours · **4 reps**
RHEL system roles, multi-host plays, `delegate_to`, `serial`.

**Gate:** one playbook configures node1 and node2 differently based on group membership.

---

### Phase 15 — Full timed EX294 runs · 10 hours · **4 runs**
**Gate:** 3 consecutive runs above 85%.

> ### ✅ RHCE READY — hour 130

---

# Ranked by leverage — if you're short on time

If you can only do part of this, do it in this order:

| Rank | Phase | Why |
|---|---|---|
| 1 | Storage | Most points, most dependencies |
| 2 | Root recovery | Gates half the real exam |
| 3 | Services + firewall | Second-biggest point block |
| 4 | Break/fix | Best interview material |
| 5 | Users & permissions | Fast points, quick to learn |
| 6 | SELinux | Silently breaks everything else |
| 7 | Everything else | |

---

# The 24-hour version

Not exam-ready. **Interview-credible with one strong demo.**

| Hours | Do |
|---|---|
| 0–4 | Storage, 5 reps |
| 4–8 | Services + firewall, 5 reps |
| 8–14 | Break/fix, 6 faults, no hints |
| 14–20 | Record the demo video |
| 20–24 | Interview talking points, said out loud |

The demo carries the interview, not recall. "Here's a broken system, watch me find it"
beats any walkthrough.

---

# What "ready" means for each goal

**Interview-ready** — you can explain the *shape* of any task out loud, and demo a live
diagnosis. You do not need flag-level recall. Roughly Phase 1–2 plus Phase 9.

**Exam-ready** — you can produce it cold, under a clock, with only `man`. That's the
whole plan.

**Job-ready** — you look things up constantly and nobody minds. Closer to interview-ready
than exam-ready, honestly.
