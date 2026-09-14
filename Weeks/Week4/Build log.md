# Building a Wazuh Blue-Team Lab — The Ups and Downs

A candid build log of what it actually took to stand up a working SIEM detection
lab, from an empty cloud account to catching a live brute-force attack. The wins
were satisfying; the roadblocks taught me more than the wins did.

---

## The wins ✅

**Got Wazuh running for free.** Landed the Oracle Cloud always-free ARM instance
(4 OCPU / 24 GB) and ran the all-in-one installer cleanly. Seeing the dashboard load
for the first time, already generating alerts about itself, was the first real
"this is working" moment.

**Stood up a realistic target.** A Windows Server 2019 domain controller (lab.local)
as the victim, Kali as the attacker, Sysmon for richer telemetry. Not a toy setup —
an actual AD environment with Kerberos, LDAP, and SMB exposed.

**Hardened it like production.** Locked the admin ports to my own IP, and replaced
the self-signed cert with a real Let's Encrypt certificate with auto-renewal. The
dashboard loads on a proper domain with a trusted padlock.

**Caught the attack end to end.** The payoff: ran a credential brute force from Kali
and watched the authentication-failure count climb in real time, correlated into a
brute-force alert and auto-mapped to MITRE ATT&CK. The full pipeline —
attacker → Windows event log → agent → SIEM → dashboard — proven in one screen.

---

## The roadblocks 🧱 (and what they taught me)

**Picking the wrong instance shape — twice.** First almost launched on a 1 GB micro
instance (way too small for Wazuh), then on a paid E3.Flex shape that would have
cost money. The free ARM shape (A1.Flex) was hidden behind a processor-series tab.
*Lesson: "free tier" and "the default selection" are not the same thing — read
before you launch.*

**The public IP that wasn't there.** Instance came up with only a private IP. Had to
dig through the VNIC → IP administration settings to assign an ephemeral public IP.
*Lesson: cloud networking doesn't assume you want to be reachable — you have to ask.*

**Oracle's two firewalls.** The single most confusing part. Opening ports in the
cloud Security List wasn't enough — the Ubuntu instance had its own iptables rules
silently blocking everything. The dashboard timed out until I opened the ports in
*both* layers. *Lesson: on Oracle, always check the host firewall too. This trips up
almost everyone.*

**The subnet mismatch saga.** Kali was on 192.168.92.x, the Windows Server on
192.168.100.x — they couldn't see each other, so no attack would land. Both VMs said
"NAT," so it made no sense... until I realised the Windows box had a **static IP**
from being promoted to a domain controller. It never took a DHCP address. Fixed by
setting a correct static IP inside the right subnet. *Lesson: when an IP refuses to
change no matter what, it's static for a reason — and DCs always are.*

**The Let's Encrypt gauntlet.** This was death by a thousand small cuts:
- Port 80 wasn't open, so the certificate challenge failed
- My DuckDNS domain pointed at my home IP, not the server — validation hit the wrong
  machine
- Ran the update command with the placeholder token still in it (got a `KO`)
- The account page gated the real token behind a reCaptcha
- Got the domain spelling wrong (wazuh vs wazuuh) more than once
- After issuing the cert, the dashboard config still pointed at the old self-signed
  files, so nothing changed until I repointed it

*Lesson: certificate automation is simple in theory and fiddly in practice. DNS,
firewall, and config all have to line up perfectly, and each one fails silently in
its own way.*

**Tooling reality checks.** hydra's SMB module choked on modern Windows SMBv2/3 —
switched to NetExec, which is what people actually use now. The rockyou wordlist
shipped compressed and had to be unzipped first. *Lesson: tutorials assume a clean
world; real tools have version quirks you only learn by hitting them.*

---

## What I'd tell someone starting this lab

The detection was the last 10%. The other 90% was cloud networking, two-layer
firewalls, VM subnets, DNS, and certificates — the unglamorous plumbing that makes
security monitoring actually work. Every roadblock above was a real skill learned,
not a distraction from the "real" work. In a SOC, that plumbing *is* the real work.

If you're building this yourself: expect the setup to take longer than the tutorials
suggest, document each problem as you solve it (that's where the portfolio value is),
and don't skip the boring hardening steps — they're the parts that look most like the
job.

---

## The stack, for reference

| Layer | Choice |
|---|---|
| SIEM | Wazuh (all-in-one) on Oracle Cloud, Ubuntu 22.04 ARM (A1.Flex, free tier) |
| TLS | Let's Encrypt via Certbot + DuckDNS, auto-renewing |
| Victim | Windows Server 2019 domain controller (lab.local) + Sysmon + Wazuh agent |
| Attacker | Kali Linux (VMware) |
| First detection | SMB/RDP brute force → Windows 4625 → Wazuh correlation → MITRE T1110 |

---

## What's next

- Scenario 2: Kerberoasting detection (Event 4769)
- Active Response: auto-block attacker IPs on correlated brute-force alerts
- A custom decoder + rule for a log source Wazuh doesn't parse natively
- Automating the whole server build with a script so it rebuilds in one command