# rhel-cert-lab

A self-hosted, **auto-graded** practice environment for the Red Hat certifications.

Most cert labs give you machines. This one gives you machines, tasks, and a grader that
inspects the live system and tells you whether the configuration is actually correct —
including whether it survives a reboot, which is where most people lose the exam.

```
$ bash grade1.sh -v

  PASS  T01  Networking (static IP, gw, DNS, hostname, secondary IP)
  PASS  T02  Users harry/natasha in admin group, tom non-interactive
  FAIL  T09  Apache serving RHCSA-OK, persistent, reachable
        - http/80 not open in permanent firewalld config
  ...
  Score: 12/15  (80%)   passing mark
```

---

## Why this exists

Red Hat's exams are performance-based. Nothing is multiple choice — a grading script
inspects the machine after you're done. So the useful practice tool isn't a question bank,
it's **a grader**.

Writing one forces you to know the difference between:

- `systemctl start` and `systemctl enable --now`
- `firewall-cmd --add-service` and `--add-service --permanent`
- a mounted filesystem and one that is in `/etc/fstab`
- `setenforce 1` and `SELINUX=enforcing` in the config file

Each of those pairs looks identical the moment you type it, and only one of each survives
a reboot. That distinction *is* the exam.

---

## What's here

| Path | Contents |
|---|---|
| `lab/` | Provisioning — builds the VMs unattended via kickstart |
| `rhcsa/tasks/` | 60 practice tasks across 4 sets, written from the published objectives |
| `rhcsa/graders/` | Four graders. Inspect live state, score against a 70% pass mark |
| `rhcsa/reference/` | Answer key, terse-command sheet, persistence rules, known pitfalls |
| `ansible/` | Idempotent provisioning for the lab nodes — doubles as EX294 practice |
| `exam/` | Exam paper UI — countdown timer, task navigation, flag/complete tracking |
| `docs/COVERAGE.md` | **Every published objective mapped to a task and an automated check** |

---

## The lab

Three VMs, mirroring the real exam layout — the environment you sit in is separate from
the machines being graded.

| VM | Role |
|---|---|
| `console` | Graphical environment. Firefox shows the exam paper and timer. Not graded. |
| `node1` | System under test |
| `node2` | Second system — proves services work from *outside*, not just localhost |

`node1` gets two spare disks so the LVM, swap and partitioning tasks are real.

---

## Design decisions worth explaining

**Graders check persistence, not command history.** Every check that can drift asks the
question a reboot would ask: is it in `/etc/fstab`, is the unit `enabled`, is the firewall
rule `--permanent`, is the value in `/etc/selinux/config`. Runtime-only state fails.

**Tasks are graded from live state.** No self-assessment, no answer comparison. `grade1.sh`
runs `swapon --show`, `nmcli con show`, `getfacl`, `semanage port -l` and decides.

**Set 3 repeats Set 1's skills with different values.** Different usernames, IPs, sizes.
If you can pass Set 1 but not Set 3, you memorised answers instead of learning the method
— which the grader will tell you.

**The unattended install uses an `OEMDRV`-labelled ISO.** Anaconda auto-detects that volume
label and runs the kickstart with zero keystrokes, so a full rebuild needs no interaction.

---

## Status

- [x] RHCSA — 60 tasks, 4 graders, full objective coverage
- [x] Unattended provisioning (Windows/VirtualBox)
- [x] Exam UI with timer
- [x] Ansible provisioning — idempotent, pure `ansible-core`, no collections needed
- [ ] Vagrant provisioning — portable, one command, any host
- [ ] RHCE (EX294) — Ansible task sets and graders

---

## Notes

Built and tested against Rocky Linux 9.8 (a RHEL rebuild from Red Hat's published sources).
The RHCSA exam targets RHEL 10; the difference is minimal at this level, and where it
matters — such as root password recovery, where `rd.break` works on RHEL 9 but not RHEL 10
— both procedures are documented in `rhcsa/reference/`.

Objectives change per release. `docs/COVERAGE.md` records the date it was verified against
Red Hat's published list. Re-check before relying on it.
