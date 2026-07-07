# Host Laptop Recovery — Post-Incident Write-up

> A record of how the host laptop broke during VM setup, what was tried to fix it,
> how it was ultimately restored, and what to change so it doesn't recur.
> Doubles as a reusable boot-recovery runbook.

- **Date of incident:** [YYYY-MM-DD]
- **Machine:** HP laptop, 8 GB RAM, Windows (UEFI boot), single NVMe/SSD
- **Context:** Building a lab VM in VMware Workstation for the Week 3 SIEM task
- **Outcome:** Recovered via professional repair (paid OS reinstall). No hardware damage.

---

## 1. Summary

While creating an Ubuntu **Desktop** VM in VMware on an 8 GB host, the machine ran
out of memory during the guest install and crashed hard. The unclean shutdown
corrupted the Windows **boot configuration** (not the data), leaving the laptop
unable to start — cycling through Automatic Repair and ending on recovery error
**0xc0000001**. Built-in recovery tools did not resolve it; the machine was taken
to a repair shop and restored with a **new OS installation**.

Crucially, throughout the failure the **drive and files were confirmed intact** —
this was a boot problem, never a data-loss problem.

---

## 2. Root cause

| Factor | Detail |
|---|---|
| Trigger | Installing a VM guest (Ubuntu Desktop) with **4 GB** allocated on an **8 GB** host |
| Mechanism | Host RAM exhausted (host OS + VMware + heavy guest GUI) → freeze → unclean power-off |
| Damage | The abrupt shutdown corrupted the **UEFI boot files / BCD**; Windows could no longer start |
| **Not** the cause | The SSD hardware was healthy and user data was untouched — verified in the recovery console |

The core mistake was **over-allocating memory on a low-RAM host** and using the
heavier **Desktop** image instead of **Server**. On 8 GB there simply wasn't enough
headroom for the host to stay stable.

---

## 3. Symptoms observed (in order)

1. `Your computer ran into a problem` → `Diagnosing your PC` (Windows Automatic Repair).
2. Brief `no operating system` / `no bootable device` message.
3. HP logo → spinner → loop back to repair (boot loop).
4. Final state: **Recovery — "Your PC couldn't start properly", error code `0xc0000001`.**

---

## 4. Recovery steps attempted

Documented in the order tried, with outcomes — useful as a runbook next time.

| # | Step | Where | Result |
|---|---|---|---|
| 1 | **Automatic Repair** | Runs on its own after crash | Did not fix |
| 2 | **System Restore** (to a restore point) | Advanced options → System Restore | **Blocked** — "You must enable system protection on this drive"; C: checkbox wouldn't tick |
| 3 | **Startup Repair** | Advanced options → Startup Repair | Did not fix |
| 4 | **Confirm data is safe** | Command Prompt → `C:` then `dir` | ✅ Windows, Users, Program Files present; **268 GB free** — proved OS/data intact |
| 5 | **Disk check** | `chkdsk C: /f /r` | Couldn't lock volume; **scheduled** for next boot (answered N to force-dismount, Y to schedule) |
| 6 | **Rebuild boot records** | `bootrec /scanos`, `bootrec /rebuildbcd` | Reported "0 Windows installations" — a known **UEFI quirk**, not actual absence |
| 7 | **Recreate boot files** | `bcdboot C:\Windows` | "Boot files successfully created" |
| 8 | Reboot | — | **0xc0000001 persisted** |
| 9 | **Escalation** | Windows install USB → Startup Repair, or repair shop | Chose the shop |
| 10 | **Professional repair** | Local shop | ✅ Restored via **new OS installation** (paid) |

### Why step 8 still failed
On UEFI systems the boot files live on a separate hidden **EFI System Partition**.
`bcdboot C:\Windows` written from the recovery console didn't fully repair that
partition, so `0xc0000001` remained. The reliable fixes for this are Startup Repair
from **Windows installation media**, or a technician (which is the route taken).

---

## 5. Resolution & cost

- **Fix applied:** Professional **OS reinstallation** at a repair shop.
- **Amount paid:** [€___]  *(typical range for a boot fix / reinstall in this area was ~€30–€80)*
- **Turnaround:** [same-day / __ days]
- **Data:** [Backed up before reinstall? yes/no — confirm your files were preserved. If a clean reinstall was done without backup, restore from your own backups.]

**Lesson embedded here:** always ask the shop to **back up files before any reinstall**.
Because the drive was healthy, the data was recoverable regardless — but a backup
makes that guaranteed rather than assumed.

---

## 6. Prevention — what changes going forward

**Sizing (the actual fix for the root cause)**
- On an 8 GB host, give a VM **2 GB (3 GB max)**, never 4 GB.
- Run **one VM at a time**; close other apps while it runs.
- Use **Ubuntu Server**, not Desktop — no GUI saves ~1 GB RAM.

**Don't run heavy tooling locally on 8 GB**
- For the Week 3 SIEM, use the **Wazuh Cloud free trial** (server runs in the cloud,
  laptop runs only a lightweight agent) instead of a local all-in-one install.

**Make the host recoverable *before* big changes**
- Turn on **System Protection** for C: and create a **restore point** first — this is
  exactly what would have made step 2 (System Restore) work.
- Keep a **Windows installation USB** on hand (Microsoft Media Creation Tool, 8 GB stick)
  so Startup Repair from media is always available.

**Protect data continuously**
- Back up important files to an **external drive** on a schedule, so a reinstall is
  never stressful.
- Snapshot **VMs** after setup so guest problems don't require rebuilds.

---

## 7. Reusable boot-recovery runbook

If a Windows machine won't boot after a crash, work through this order. All steps
below are **non-destructive to personal files**:

1. Let **Automatic Repair** run once.
2. **Advanced options → Startup Repair.**
3. **Advanced options → System Restore** (needs a prior restore point).
4. **Advanced options → Command Prompt**, then:
   ```
   C:
   dir                      (confirm Windows/Users folders exist — proves data is safe)
   chkdsk C: /f /r          (N to force-dismount, Y to schedule at restart)
   bcdboot C:\Windows       (recreate boot files)
   ```
5. If error persists (e.g. **0xc0000001**), boot from a **Windows installation USB**
   and run **Repair your computer → Startup Repair** (fixes the EFI partition properly).
6. If still stuck, a **repair shop** resolves boot issues quickly — and ask them to
   **back up files first**. A healthy drive means data is recoverable either way.

**Golden rule:** a boot failure is almost never data loss. Confirm the files are on
the disk (`dir C:`) before doing anything drastic, and never choose "Reset → Remove
everything" or reinstall-without-backup while stressed.

---

## 8. Silver lining

This is, in effect, a real **incident write-up** — timeline, root-cause analysis,
remediation steps, and preventive controls. That's the same structure used for
security incident reports (Week 5's deliverable), so the painful evening produced a
genuinely useful portfolio artifact and a runbook you'll reuse.

---

*Personal lab notes — kept so the next problem is a checklist, not a panic.*
