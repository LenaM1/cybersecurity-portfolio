# Scenario 1 — Credential Brute Force Against a Domain Controller

**Detection lab case study | Wazuh SIEM**
MITRE ATT&CK: T1110 (Brute Force), T1078 (Valid Accounts), T1087 (Account Discovery)

---

## Summary

A credential brute-force attack was launched from a Kali Linux host against the
`administrator` account of a Windows Server 2019 domain controller. Wazuh detected
the attack by ingesting Windows security events from the endpoint agent, surfacing
the failed authentication attempts and correlating them into brute-force alerts,
then automatically mapping the activity to MITRE ATT&CK techniques.

This validates the full detection pipeline end to end: attacker action → Windows
event log → Wazuh agent → Wazuh manager → dashboard alert.

---

## Environment

| Component | Role | Detail |
|---|---|---|
| Wazuh server | SIEM (indexer + server + dashboard) | Oracle Cloud, Ubuntu 22.04 ARM (A1.Flex), Let's Encrypt TLS |
| DC01 | Victim / monitored endpoint | Windows Server 2019, domain `lab.local`, Wazuh agent + Sysmon |
| Kali | Attacker | VMware, same NAT subnet as the victim (192.168.92.0/24) |

Network: attacker `192.168.92.128`, victim `192.168.92.10`. Agent reports to the
Wazuh server over the internet on 1514/1515.

---

## Attack

Reconnaissance with nmap confirmed the target was a domain controller (Kerberos 88,
LDAP 389/636, Global Catalog 3268/3269, SMB 445, RDP 3389 all open) running
Windows Server 2019 (build 17763), hostname `DC01`, domain `lab.local`.

The brute force itself was run with NetExec (the modern SMB tool; hydra's SMB module
fails against SMBv2/3 on current Windows). A short custom password list was used
rather than a full wordlist — the goal is to generate a burst of failed logons to
trigger detection, not to actually crack the account.

```bash
# Recon
nmap -Pn 192.168.92.10

# Brute force (deliberately wrong passwords → failed logons)
nxc smb 192.168.92.10 -u administrator \
    -p Password123 Admin123 Welcome1 P@ssw0rd Letmein1 \
       Summer2024 Spring2025 Company123 Fall2024 Winter2025
```

Each attempt returned `STATUS_LOGON_FAILURE`, and each failure wrote a
Windows Event ID **4625** (an account failed to log on) to the DC's security log.

---

## Detection

The Wazuh agent forwarded the 4625 events to the manager, where built-in rules
matched them. In the Threat Hunting dashboard the **Authentication failure** count
rose in step with the attack (observed climbing from 9 to 19 across two bursts),
while legitimate activity continued to register under Authentication success.

Rules involved:

| Rule ID | Level | Meaning |
|---|---|---|
| 60122 | 5 | Windows logon failure — unknown user or bad password (individual 4625) |
| 60204 | 10 | Multiple Windows logon failures from same source (brute-force correlation) |

The individual `60122` alerts are the raw failed logons. The `60204` correlation
rule is the important one: it fires when many failures stack up in a short window,
which is what turns "some noise" into a **detected brute-force attack**. This showed
up as a level-10 spike in the Alert Level Evolution chart.

Wazuh automatically mapped the activity in the MITRE ATT&CK panel to Valid Accounts,
Account Discovery, and Domain Accounts — consistent with credential attacks against
an AD account.

---

## Evidence

- Threat Hunting dashboard showing the authentication-failure count rising during the attack
- Alert Level Evolution chart showing the level-10 spike
- MITRE ATT&CK panel populated with Valid Accounts / Account Discovery
- (Optional) the individual 4625 events drilled down from the failure panel, showing
  source workstation and the targeted `administrator` account

*Add screenshots here in the repo.*

---

## Blue-team analysis

**What worked.** The detection required no custom rules — Wazuh's out-of-the-box
ruleset caught both the individual failures and the aggregate pattern. Sysmon was
installed on the endpoint, enriching the telemetry available for follow-on analysis.

**Tuning considerations.** In production the `60204` threshold and time window would
be tuned to the environment's baseline to balance detection speed against false
positives from, e.g., a user with a stale cached password. The alert email level
was set to 10+ so only correlated brute-force events page an analyst, not every
single failed logon.

**Response.** This is a strong candidate for Wazuh Active Response: on rule `60204`,
an automated `firewall-drop` action can block the source IP for a timeout period,
containing the attack without analyst intervention. (Implemented in a later scenario.)

**Hardening the target.** Account lockout policy, disabling the built-in
Administrator for remote logon, restricting RDP/SMB exposure, and enforcing strong
passwords would all reduce the real-world risk this scenario simulates.

---

## Skills demonstrated

SIEM deployment and endpoint onboarding · Windows security-event log analysis ·
brute-force detection and alert correlation · MITRE ATT&CK mapping ·
attacker/victim lab construction · incident triage from a SIEM dashboard.