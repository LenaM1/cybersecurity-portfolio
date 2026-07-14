# Week 3 — Standing Up a SIEM with Wazuh

> **Project:** Cybersecurity Portfolio · Week 3 (Blue Team)
> **Author:** Mercy Lena
> **Date:** 2026-07-14
> **Deliverable:** Working Wazuh dashboard + setup guide
> **Status:** SIEM installed and dashboard reached ✅ · agent enrollment pending

---

## 1. Objective

Deploy a Security Information and Event Management (SIEM) platform — the central
system that collects, analyses, and alerts on logs from other machines — and bring
up its web dashboard. Wazuh (open source, free) was chosen for its all-in-one
installer and friendly learning curve.

The goal for the week: a **running Wazuh dashboard**, reachable from the host
browser, ready to receive logs from agents.

---

## 2. Environment & Prerequisites

| Component | Value |
|---|---|
| Host | HP laptop, 16 GB RAM, Windows, VMware Workstation |
| SIEM VM | Ubuntu Server 22.04 LTS (no desktop — leaner) |
| VM resources | 4 GB RAM, 2 vCPU, 40 GB disk, NAT adapter |
| Wazuh version | 4.14 (all-in-one) |
| Access | Dashboard opened from the **host** browser (VM has no GUI) |

**Why Ubuntu Server, not Desktop:** no graphical environment saves ~1 GB of RAM and
keeps the VM lean — important since the Wazuh indexer is memory-hungry. The dashboard
is reached over the network from the host, so a GUI inside the VM is unnecessary.

---

## 3. Architecture

Wazuh was deployed **all-in-one**: the three core components run together on the
single Ubuntu VM.

```
[ Ubuntu Server VM ]  ── Wazuh indexer  (stores & searches alert data)
  192.168.133.129     ── Wazuh server   (collects logs, runs detection rules)
                      ── Wazuh dashboard (web UI, reached from host browser)
        ▲
        │  (planned)
   [ Kali / other VMs ] running Wazuh agents → ship logs to the server
```

Reached at: `https://192.168.133.129` (self-signed certificate — the browser "not
secure" warning is expected in a lab).

---

## 4. Installation

The Wazuh assistant handles the GPG key, repository, and all three components:

```bash
# Download and run the all-in-one installer
curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh
sudo bash ./wazuh-install.sh -a
```

On completion the installer prints the dashboard URL and the generated admin
credentials, and saves everything to `wazuh-install-files.tar`.

![Wazuh install completing](screenshots/01-install-progress.png)
*Figure 1 — the installer setting up internal users and Filebeat during final config.*

![Wazuh dashboard login](screenshots/02-dashboard-login.png)
*Figure 2 — the Wazuh dashboard reached from the host browser at https://192.168.133.129.*

---

## 5. Problems Encountered & Fixes

The install did not succeed on the first run. Diagnosing and fixing it was the most
valuable part of the week.

### 5.1 Dashboard install failed — disk full (not memory)

The first run installed the indexer, server, and Filebeat successfully, then failed
on the **dashboard** and rolled everything back. The initial assumption was memory,
but the evidence said otherwise:

```bash
free -h        # showed 2.6 GB free — memory was NOT the problem
df -h /        # root filesystem only 19 GB, nearly full
```

The install log named the real cause directly:

```
dpkg-deb: error: ... disk full ...
```

**Root cause:** the VM's disk was created at 40 GB, but Ubuntu's guided **LVM** setup
only allocated ~19 GB to the root filesystem, leaving ~19 GB unused inside the volume
group. The dashboard needed ~1 GB to unpack and hit "disk full" despite the disk
having plenty of unclaimed space.

**Fix — claim the unused LVM space:**

```bash
sudo vgs      # confirmed ~19 GB VFree in the volume group
sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv
df -h /       # root grew from 19 GB to ~38 GB
```

Then clear the partial download and re-run the installer with the **overwrite** flag:

```bash
sudo apt clean
sudo bash ./wazuh-install.sh -a -o
```

The `-o` wipes the rolled-back remnants so the install starts clean. This time all
four components — indexer, server, Filebeat, and **dashboard** — completed.

> **Lesson:** "disk full" and "out of memory" produce different errors — always read
> the log and check `free -h` / `df -h` before assuming. And Ubuntu's guided LVM
> often leaves half the disk unallocated; `lvextend` + `resize2fs` reclaims it with no
> reinstall.

### 5.2 Dashboard login rejected — ambiguous generated password

The dashboard loaded but rejected the admin login. The installer's generated password
contained look-alike characters (capital `I` vs lowercase `l` vs `1`), which are easy
to mistype. The exact password can always be read back from the install bundle:

```bash
sudo tar -O -xf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt
# look for the block: indexer_username: 'admin' / indexer_password: '...'
```

### 5.3 Setting a clean admin password

Rather than fight the generated string, the admin password was reset with Wazuh's
tool. Note the **allowed symbols are limited to** `. * + ? -` (an `!` is rejected):

```bash
sudo /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh \
  -u admin -p '<NewPassword->'   # must include upper, lower, digit, and one of . * + ? -
```

Wait ~30–60 seconds for the change to propagate to the indexer, then log in as
`admin`.

> **Security note:** never commit real passwords to the repo. Use a placeholder here
> and keep actual credentials out of version control.

---

## 6. Result

- Wazuh 4.14 all-in-one **installed and running** on the Ubuntu VM.
- Dashboard **reachable and rendering** at `https://192.168.133.129`.
- Admin authentication working after the password reset.

This satisfies the Week 3 core objective: a live SIEM with a working dashboard.

---

## 7. Remaining Work

- **Enrol agents** (Kali and other VMs) to ship logs to the server — turning the
  single-node SIEM into a multi-host one.
- **Cap the indexer heap** (`/etc/wazuh-indexer/jvm.options`, set `-Xms`/`-Xmx` to
  ~1 GB) to keep the 4 GB VM stable.
- Generate test activity (failed logins, new user) and confirm alerts appear —
  leading into Week 4 (detection engineering).

> Note: agent enrolment was deferred because the host laptop developed a separate
> hardware/boot fault (documented in `laptop-recovery-postmortem.md`). The remaining
> steps will be completed on a repaired machine or via **Wazuh Cloud**, where the
> heavy server runs remotely and the laptop only runs a lightweight agent.

---

## 8. Key Takeaways

- A SIEM has two halves: a **server/indexer/dashboard** that analyses logs, and
  **agents** on endpoints that ship them.
- **Diagnose from evidence, not assumption** — the "memory" theory was wrong; the log
  and `df -h` proved it was disk.
- **Ubuntu guided LVM under-allocates the disk**; reclaim it with `lvextend` +
  `resize2fs`.
- Generated credentials with look-alike characters are worth replacing early; know
  the allowed-symbol set before resetting.
- On limited hardware, prefer **Ubuntu Server** over Desktop and cap the indexer's
  memory — or run the SIEM in the cloud.

---

## Appendix — screenshot mapping

Drop the relevant captures in `screenshots/` and rename to match the figures:

| Screenshot | Rename to | Shows |
|---|---|---|
| Install final-config log | `01-install-progress.png` | Installer setting up users / Filebeat |
| Dashboard login page | `02-dashboard-login.png` | Wazuh dashboard reached from host |
| (optional) disk-full log line | `03-disk-full-error.png` | The dpkg "disk full" error |
| (optional) `df -h` before/after | `04-lvextend-fix.png` | Root filesystem grown to ~38 GB |

---

*Part of my cybersecurity portfolio · Week 3 (Blue Team — SIEM deployment).*
