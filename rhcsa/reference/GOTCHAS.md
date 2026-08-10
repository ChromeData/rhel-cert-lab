# What actually trips people up

Sourced from Red Hat's own candidate community and first-hand pass/fail write-ups — not
from memory. Where something is a direct candidate report it's marked **[reported]**.

**Limitation, stated plainly:** Reddit blocks Anthropic's crawler entirely, and YouTube
doesn't expose transcripts to my fetcher. So this comes from the Red Hat Learning
Community, published cert guides, and personal exam write-ups. It is not a survey of
r/redhat.

---

## Confirmed exam facts

| | |
|---|---|
| Duration | **3 hours** [reported] |
| Scoring | **300 points, 210 to pass (70%)** [reported] |
| Systems | **Two VMs — node1 and node2** [reported] |
| How you reach them | A **"VM View" icon in the Activities menu** on the base machine [reported] |
| Where the details live | IPs and root passwords are in a **Firefox hyperlink** — read everything before starting [reported] |
| After finishing | There is **review time** to go back and correct [reported] |

⚠ **Do not change the base/physical machine's root password.** [reported] Only the exam VMs.

---

## The failure patterns people actually report

### 1. Scanning instead of reading
The most cited failure. Candidates skim and miss a clause. **[reported]** Read each task
word for word. A task that says "without disturbing existing settings" is testing one
specific flag.

### 2. Interdependent questions
Questions build on each other — **failing an early one can zero a later one.** **[reported]**
This is why the advice is to work **in the given order**, not to cherry-pick.

### 3. Typos, especially `1` vs `l`
Specifically called out. **[reported]** Hostnames and usernames are where this bites.
Verify with `getent`/`hostnamectl` rather than trusting what you typed.

### 4. Storage task ordering
Doing a storage task one way can leave insufficient space for a later one. **Read all the
storage tasks before starting any of them** — then execute in order.

### 5. Root password recovery
People fail because they can't get into single-user / `rd.break` — unfamiliar kernel
parameters under pressure. **[reported]** Drill this until it's automatic.

### 6. Containers
Multiple candidates report containers as the topic that failed them. **[reported]**

### 7. Persistence — the big one
The classic pattern: service started but not enabled · mount works but fstab is wrong ·
SELinux set permissive at runtime instead of properly configured · firewall rule not
`--permanent` · network works now but not after reboot.

**Always reboot after storage work**, and after anything that could stop the root
filesystem mounting.

---

## Correction to advice I gave you earlier

I told you to do **storage tasks first**. That comes from published cert guides and it is
reasonable in isolation.

But a first-hand account says: **work in the order given, because Red Hat's questions are
interdependent.** Jumping around risks doing task 9 before the task 4 it depends on.

**Your instinct was right and mine was wrong.** Go in order. Read all the storage tasks
first so you can plan disk space — but *execute* in sequence.

---

## The pre-reboot checklist

Before every reboot, and once more before you finish:

```bash
mount -a
```
Silence = safe. An error = fix it now, not later.

```bash
systemctl is-enabled <every service you touched>
```

```bash
firewall-cmd --permanent --list-all
```

```bash
getenforce && grep ^SELINUX= /etc/selinux/config
```

Then reboot and re-verify. Use the review time at the end for exactly this.

---

## Sources

- [Red Hat Learning Community — candidate threads](https://learn.redhat.com/t5/Platform-Linux/Why-am-I-failing-my-RHCSA-V9-exam/td-p/35520)
- [Om Deore — How to Pass RHCSA (EX200), first-hand V9 experience](https://medium.com/@omdeoree16/how-to-pass-rhcsa-ex200-my-rhcsa-experience-latest-v9-a25e58b69857)
- [Pluralsight — Red Hat Exams: A Few Tips](https://www.pluralsight.com/resources/blog/cloud/red-hat-exams-a-few-tips)
- [Red Hat EX200 objectives](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
