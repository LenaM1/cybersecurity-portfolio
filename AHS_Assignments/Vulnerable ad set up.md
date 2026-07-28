# Vulnerable Active Directory Home Lab Setup

## Overview

This project documents the complete setup of a **vulnerable Active Directory (AD) home lab** designed for security research, penetration testing practice, and hands-on learning of Active Directory attacks and defense mechanisms.

The lab replicates common real-world misconfigurations and security weaknesses found in production environments, making it an ideal platform for learning offensive and defensive AD security techniques.

---

## Lab Architecture

### Virtual Environment
- **Hypervisor:** VMware Workstation
- **Network:** Isolated virtual network (192.168.100.0/24)
- **Air-gapped:** No internet access for safety

### Virtual Machines
```
Network: 192.168.100.0/24

DC01                    192.168.100.10    Domain Controller (Windows Server 2019)
                                          - Active Directory Domain Services
                                          - DNS Server
                                          - Domain: lab.local
```

### Specifications
- **OS:** Windows Server 2019 Standard (Evaluation)
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 60 GB
- **Network:** NAT/Host-only (isolated)

---

## Domain Structure

### Domain Information
```
Domain Name:    lab.local
Forest Root:    lab.local
Domain Controller: DC01
```

### Organizational Units (OUs)
```
lab.local
├── Admins
├── ServiceAccounts
└── StandardUsers
```

---

## Users Created

### Administrative Accounts
These accounts have Domain Admin privileges with intentionally weak passwords for practice:

| Username | Password | Description |
|----------|----------|-------------|
| jadmin | Admin123 | John Admin - Domain Admin |
| jladmin | Welcome1 | Jane Admin - Domain Admin |
| badmin | Letmein1 | Bob Admin - Domain Admin |

### Service Accounts
Service accounts with credentials stored in AD description fields (common real-world vulnerability):

| Username | Password | Description | SPN |
|----------|----------|-------------|-----|
| sqlsvc | SQLPass@123 | SQL Service - Password: SQLPass@123 | MSSQLSvc/server01.lab.local:1433 |
| websvc | WebApp2024! | IIS Service - Password: WebApp2024! | HTTP/webserver.lab.local |
| backupsvc | Backup123 | Backup Service - Pass: Backup123 | backup/server01.lab.local |
| printsvc | Print@456 | Print Service - Password: Print@456 | None |

### Standard Domain Users
Regular users with weak and reused passwords:

| Username | Password | Department |
|----------|----------|-----------|
| ajohnson | Welcome123 | Finance |
| bsmith | Password123 | HR |
| cbrown | Qwerty123 | IT |
| dprince | Dprince@123 | Executive |
| enorton | Welcome123 | Development |

**Note:** enorton and ajohnson share the same password (intentional reuse vulnerability).

---

## Security Groups

### Department Groups
```
IT_Staff
  ├── jadmin
  └── jladmin

Finance_Department
  ├── ajohnson
  └── bsmith

Development_Team
  ├── cbrown
  └── enorton

Executives
  ├── jladmin
  └── dprince
```

### Privilege Escalation Groups (Nested)
```
Domain Admins
  └── Nested_Admins
      └── IT_Staff
          ├── jadmin
          └── jladmin
```

This nested structure allows practice in privilege escalation through group membership chains.

---

## Intentional Vulnerabilities

### 1. Weak Passwords
- Admin accounts: Simple, common passwords (Admin123, Welcome1, Letmein1)
- Standard users: Dictionary passwords (Welcome123, Password123, Qwerty123)
- **Attack vector:** Credential spraying, dictionary attacks, brute force

### 2. Credentials in Description Fields
- Service accounts have plaintext passwords in their AD descriptions
- Example: "DB service account - Password: SQLPass@123"
- **Attack vector:** LDAP enumeration, AD object property dumping

### 3. Service Principal Names (SPNs)
- Multiple user accounts have SPNs configured
- **Attack vector:** Kerberoasting - extract and crack service ticket hashes

SPNs configured:
```
sqlsvc:
  - MSSQLSvc/server01.lab.local:1433
  - MSSQLSvc/server01.lab.local

websvc:
  - HTTP/webserver.lab.local

backupsvc:
  - backup/server01.lab.local
```

### 4. Reused Passwords
- ajohnson and enorton both use: Welcome123
- **Attack vector:** Once one account is compromised, the other is also accessible

### 5. Nested Group Memberships
- Privilege escalation paths through group nesting
- **Attack vector:** BloodHound analysis, privilege escalation chains

### 6. No Security Hardening
- Default security settings
- No advanced security policies configured
- **Attack vector:** Pass-the-hash, Kerberos delegation attacks, etc.

---

## Attack Scenarios & Practice Areas

### 1. User Enumeration
```powershell
# Enumerate all users
Get-ADUser -Filter * | Select Name, SamAccountName

# Enumerate service accounts
Get-ADUser -Filter {ServicePrincipalNames -like '*'} -Properties ServicePrincipalNames
```

### 2. Credential Spraying
Use weak passwords against multiple accounts:
```
Admin123
Welcome1
Welcome123
Password123
Qwerty123
SQLPass@123
```

### 3. Kerberoasting
Extract and crack service account ticket hashes:
```bash
python3 GetUserSPNs.py lab.local/ajohnson:Welcome123 -dc-ip 192.168.100.10
```

### 4. AS-REP Roasting
(Accounts with pre-authentication disabled - can be added for practice)

### 5. Privilege Escalation
Via nested group memberships:
```
Low-privilege user → Finance_Department → (escalate via group membership)
```

### 6. LDAP Enumeration
Query AD for sensitive information:
```bash
ldapsearch -H ldap://192.168.100.10 -D "CN=ajohnson,CN=Users,DC=lab,DC=local" \
  -w Welcome123 -b "DC=lab,DC=local" "(objectClass=*)"
```

### 7. Group Policy Attacks
(Can be added: credentials in GPO scripts, misconfigured permissions)

---

## Tools for Lab Testing

### Reconnaissance
- `nslookup` - DNS queries
- `nmap` - Network scanning
- `enum4linux` - LDAP enumeration
- `ldapsearch` - LDAP queries

### Enumeration
- **BloodHound** - AD mapping and attack paths
- **Invoke-ShareFinder** - Share enumeration
- **Get-GPPPassword** - Group Policy credential hunting
- **AdExplorer** - AD browser

### Exploitation
- **Mimikatz** - Credential dumping, pass-the-hash
- **Rubeus** - Kerberos ticket manipulation
- **PowerSploit** - Privilege escalation scripts
- **SharpHound** - BloodHound data collector

### Defense & Audit
- **PingCastle** - AD security audit
- **BloodHound (Blue Team)** - Defensive analysis
- **Windows Event Viewer** - Security event logging
- **Active Directory Administrative Center** - AD management

---

## Setup Instructions

### Prerequisites
- VMware Workstation or equivalent hypervisor
- Windows Server 2019 Evaluation ISO
- 60GB+ free disk space
- 8GB+ RAM available

### Installation Steps

1. **Create Virtual Machine**
   - CPU: 2 cores, RAM: 4GB, Disk: 60GB
   - Network: Host-only/NAT (isolated)
   - Mount Windows Server 2019 ISO

2. **Install Windows Server 2019**
   - Edition: Standard
   - Installation: Custom (clean install)
   - Skip product key during installation

3. **Post-Installation Configuration**
   ```powershell
   # Set static IP
   New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.100.10 -PrefixLength 24 -DefaultGateway 192.168.100.1
   
   # Rename to DC01
   Rename-Computer -NewName "DC01" -Restart
   
   # Install AD DS
   Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Restart
   
   # Promote to Domain Controller
   Install-ADDSForest -DomainName "lab.local" -SafeModeAdministratorPassword (ConvertTo-SecureString "SafeP@ss123!" -AsPlainText -Force) -Force
   ```

4. **Create Users and Groups**
   - Run PowerShell scripts provided in this lab
   - Create OUs, users, service accounts
   - Configure group memberships
   - Add SPNs for Kerberoasting

5. **Snapshot VM**
   - Take VM snapshot: "DC01-Clean-AD"
   - Use for resetting lab between tests

---

## Lab Snapshots & Checkpoints

### DC01-Clean-AD
- Clean Domain Controller state
- All users and groups created
- No compromise or artifacts
- **Use:** Reset lab to known good state

---

## Security Notes & Lab Safety

### Important
⚠️ **This lab is intentionally vulnerable and should ONLY run:**
- On isolated, air-gapped networks
- In VMs with no access to production systems
- In personal lab environments only
- With proper access controls

### Isolation Requirements
```
✅ Virtual network isolated from host network
✅ No internet access for lab VMs
✅ No connection to production network
✅ Separate VM snapshots for clean states
✅ Regular backups stored separately
```

### Lab Reset Procedure
1. Restore from clean snapshot
2. Verify no unauthorized access occurred
3. Run security audit
4. Resume testing

---

## Lab Maintenance

### Regular Checks
```powershell
# Verify domain health
dcdiag /c /v

# Check AD replication
repadmin /replsummary

# List all users
Get-ADUser -Filter * | Select Name, SamAccountName

# Verify SPNs
Get-ADUser -Filter {ServicePrincipalNames -like '*'} -Properties ServicePrincipalNames
```

### Password Resets
```powershell
# If user password needs reset
Set-ADAccountPassword -Identity "username" -NewPassword (ConvertTo-SecureString "NewPassword!" -AsPlainText -Force) -Reset
```

### Add New Users
```powershell
New-ADUser -Name "New User" `
    -SamAccountName "newuser" `
    -UserPrincipalName "newuser@lab.local" `
    -Path "OU=StandardUsers,DC=lab,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) `
    -Enabled $true
```

---

## Learning Path

### Beginner (Week 1)
1. User enumeration with net/PowerShell
2. Weak password identification
3. Basic LDAP queries
4. Group structure analysis
5. Credential spraying with identified passwords

### Intermediate (Week 2-3)
1. Kerberoasting attacks
2. Group membership exploitation
3. Privilege escalation paths
4. BloodHound analysis
5. Service account enumeration

### Advanced (Week 4+)
1. Defensive hardening
2. Security monitoring setup
3. Event log analysis
4. Detection engineering
5. Remediation strategies

---

## Extending the Lab

### Suggested Additions
- **Member Servers:** File server, Web server, SQL server
- **Workstations:** Windows 10/11 joined to domain
- **Attack VM:** Kali Linux for external attack simulation
- **Group Policy Vulnerabilities:** Passwords in GPO, misconfigured permissions
- **Exchange Server:** For email-based attacks
- **LAPS:** Local Administrator Password Solution (for defensive practice)

---

## References & Resources

### Microsoft Documentation
- [Active Directory Overview](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/get-started-with-active-directory-domain-services)
- [Group Policy](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-firewall/windows-firewall-with-advanced-security)

### Security Research
- [MITRE ATT&CK - Kerberoasting](https://attack.mitre.org/techniques/T1558/003/)
- [MITRE ATT&CK - Credential Dumping](https://attack.mitre.org/techniques/T1003/)

### Tools
- [BloodHound](https://github.com/BloodHoundAD/BloodHound)
- [Impacket GetUserSPNs](https://github.com/fortra/impacket)
- [Rubeus](https://github.com/GhostPack/Rubeus)
- [Mimikatz](https://github.com/gentilkiwi/mimikatz)

---

## Changelog

### Version 1.0 (July 2026)
- Initial lab setup
- Domain Controller configuration
- User and group creation
- SPN configuration for Kerberoasting
- Documentation completed

---

## Author Notes

This lab was built to provide hands-on experience with Active Directory security concepts in a safe, controlled environment. The intentional vulnerabilities mirror common real-world misconfigurations found during penetration tests.

**Key Learning Outcomes:**
- Understanding AD architecture and trust relationships
- Identifying common AD misconfigurations
- Practicing attack techniques in a safe environment
- Developing defensive monitoring strategies
- Building security awareness for both attackers and defenders

---

## Questions & Support

For issues, suggestions, or improvements to this lab:
- Document findings and test cases
- Create issues in the repository
- Share defensive strategies and hardening techniques
- Contribute additional lab scenarios

---

**Last Updated:** July 28, 2026

**Status:** ✅ Fully Operational

## Proof of lab-set-up:
![Active Directory Setup](./vulnerable%20ad%20images/Active-Directory.png)

![Admin Controller](./vulnerable%20ad%20images/Admin_controller.png)

![Admins with Weak Pass](./vulnerable%20ad%20images/Admins_with_weak_pass.png)

![DNS Setup](./vulnerable%20ad%20images/DNS-Set-up.png)

![Service Accounts Created](./vulnerable%20ad%20images/Service_Acc_Created.png)

![Service Groups Nested](./vulnerable%20ad%20images/Servicegrps_with_nested_membersh.png)

![SPNs for Kerberoasting](./vulnerable%20ad%20images/SPNs_for_kerberoasting.png)

![SPNs Verified](./vulnerable%20ad%20images/SPNs_Verified.png)

![Standard Users Weak Pass](./vulnerable%20ad%20images/Standard_Users_with_weak_pass.png)

![Verify Admin Users](./vulnerable%20ad%20images/Verify_Admin_Users.png)
---