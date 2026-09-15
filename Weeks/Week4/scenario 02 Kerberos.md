# Scenario 2 — Kerberoasting: A Detection-Gap Investigation

**Detection lab case study | Wazuh SIEM**
MITRE ATT&CK: T1558.003 (Kerberoasting)

---

## Summary

This scenario set out to detect a Kerberoasting attack against an Active Directory
domain controller. The attack itself succeeded easily — service tickets were
requested and cracked offline. Detecting it, however, turned into a multi-layer
investigation that surfaced three separate reasons the "textbook" detection fails on
a modern, default-configured environment.

The value of this scenario is not a single green alert. It is the demonstration that
detection is a **pipeline** — attacker action → Windows event → audit policy →
agent forwarding → SIEM rule — and that a gap at any layer makes the attack
invisible, regardless of how good the final rule is. Working through those layers is
the core skill of a detection engineer.

---

## Environment

Same lab as scenario 1: Wazuh server on Oracle Cloud, Windows Server 2019 domain
controller (`DC01`, `lab.local`) with the Wazuh agent + Sysmon, and a Kali attacker
on the same subnet. The domain contained several service accounts with registered
SPNs (`svc-sql`, `sqlsvc`, `websvc`, `backupsvc`), each a valid Kerberoasting target.

---

## The attack

Kerberoasting abuses a normal Kerberos feature: any authenticated domain user can
request a service ticket (TGS) for any account with a Service Principal Name, and
that ticket is encrypted with the service account's password hash. The attacker
requests the tickets, then cracks them offline — no elevated privileges required,
and nothing is written to the target service.

```bash
# Recon confirmed a domain controller (Kerberos, LDAP, GC, SMB all open)
nmap -Pn 192.168.92.10

# Request service tickets for all SPN accounts
impacket-GetUserSPNs lab.local/administrator:'<password>' \
    -dc-ip 192.168.92.10 -request -outputfile kerberoast.hash

# Offline crack
hashcat -m 13100 kerberoast.hash /usr/share/wordlists/rockyou.txt
```

GetUserSPNs returned crackable `$krb5tgs$` hashes for every SPN account. The attack
worked exactly as intended.

---

## The detection investigation

The goal was to detect this in Wazuh. Each step below is a gap that had to be closed.

### Gap 1 — The RC4 signature doesn't fire on modern AD

The classic Kerberoasting detection keys on **RC4-encrypted** service tickets
(encryption type `0x17`), because attackers historically forced RC4 as the weakest,
fastest-to-crack cipher. Inspecting the actual events told a different story:

```bash
sudo grep -a '4769' /var/ossec/logs/alerts/alerts.json \
  | grep -o '"ticketEncryptionType":"[^"]*"' | sort | uniq -c
#   -> 23 "ticketEncryptionType":"0x12"     (AES)
```

Every ticket came back as **AES (`0x12`)**, not RC4. Modern impacket against Windows
Server 2019 negotiates AES by default. A detection rule keyed on RC4 would never
have fired. **Lesson: signatures age; the environment's defaults had moved on from
the tutorials.**

### Gap 2 — Windows wasn't auditing service-ticket operations

Pivoting to a behavior-based approach (detect the *pattern* of many service-ticket
requests rather than the cipher) required the events to name the target service
accounts. They didn't:

```bash
sudo grep -a '4769' /var/ossec/logs/alerts/alerts.json \
  | grep -o '"serviceName":"[^"]*"' | sort | uniq -c
#   -> only DC01$ (machine account) and krbtgt — never svc-sql et al.
```

The reason: **"Audit Kerberos Service Ticket Operations" is not enabled by default**
on a domain controller. Without it, the DC logs TGT activity but not the per-SPN TGS
requests that Kerberoasting generates. Enabling it:

```powershell
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable
auditpol /get /subcategory:"Kerberos Service Ticket Operations"   # -> Success and Failure
```

Verified on the DC afterward that the events now existed locally:

```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4769} -MaxEvents 30 |
  Where-Object { $_.Message -match 'svc-sql' }
#   -> multiple svc-sql 4769 events, correctly logged on the DC
```

**Lesson: you cannot detect what you do not log. Audit policy is the first
prerequisite of any Windows detection, and its defaults are conservative.**

### Gap 3 — The events reach Windows but not the SIEM

With auditing on and svc-sql 4769 events confirmed in the DC's own Security log, the
same events still did not appear in Wazuh — only the older `DC01$`/`krbtgt` ones did.
The break was isolated to the telemetry pipeline **between the endpoint and the
SIEM**: the events exist on the domain controller but are not surfacing as alerts on
the manager.

Investigation ruled out several causes: the Wazuh agent was confirmed alive and
actively forwarding other events; the Security channel's query filter was inspected
and does **not** exclude event 4769; the agent was restarted to reload configuration.
At the time of writing, the exact cause of the endpoint-to-SIEM gap for these
specific events remains under investigation — a genuine, unresolved telemetry
problem of exactly the kind a SOC engineer works through.

**Lesson: even with logging enabled and a correct rule, the pipeline between agent
and SIEM is its own failure domain and must be validated end to end.**

---

## The detection rule (ready for when telemetry is confirmed)

The behavior-based rule written for this scenario detects a burst of service-ticket
requests for non-machine accounts, independent of encryption type — a more durable
signal than the RC4 signature, since it catches AES Kerberoasting too:

```xml
<group name="windows,kerberos,attack,">

  <!-- Service ticket requested for a non-machine (service) account -->
  <rule id="100201" level="5">
    <if_sid>60106</if_sid>
    <field name="win.system.eventID">^4769$</field>
    <field name="win.eventdata.serviceName">^[^$]+$</field>
    <description>Kerberos service ticket requested for service account: $(win.eventdata.serviceName)</description>
  </rule>

  <!-- Burst of such requests in a short window = Kerberoasting -->
  <rule id="100202" level="12" frequency="4" timeframe="30">
    <if_matched_sid>100201</if_matched_sid>
    <description>Kerberoasting attack detected: rapid service-account ticket requests</description>
    <mitre><id>T1558.003</id></mitre>
  </rule>

</group>
```

---

## Blue-team analysis

**Why RC4 signatures are insufficient.** Detections that rely on RC4 downgrade
requests are increasingly blind as environments move to AES. A robust Kerberoasting
detection keys on behavior — volume and diversity of SPNs requested by a single
principal in a short window — not on the cipher.

**Logging is the foundation, not the rule.** Two of the three gaps here were about
telemetry existing at all (audit policy) and arriving (agent forwarding), not about
detection logic. In real environments this is typical: most "we didn't catch it"
post-mortems trace to a missing log source, not a missing rule.

**Hardening the target.** Service accounts should use long, random passwords (25+
characters / group Managed Service Accounts), which make offline cracking
infeasible regardless of detection. In this lab, accounts whose passwords were not in
the wordlist resisted cracking entirely — the defensive lesson in miniature.

---

## Status

- Attack: **successful** (tickets requested and dumped)
- Audit policy gap: **identified and fixed**
- RC4-vs-AES signature gap: **identified and understood**
- Endpoint-to-SIEM telemetry gap: **identified, under investigation**
- Custom detection rule: **written, pending telemetry confirmation**

---

## Skills demonstrated

Active Directory attack execution (Kerberoasting) · Kerberos protocol understanding
(TGS, encryption types) · Windows audit policy configuration · end-to-end telemetry
pipeline troubleshooting (endpoint log → agent → SIEM) · detection rule authoring ·
recognizing that detection engineering spans the whole pipeline, not just rules.