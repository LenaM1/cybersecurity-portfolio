# Resetting a Forgotten Ubuntu Password (Recovery Mode)

> How to reset a local user's password on an Ubuntu VM when you're locked out —
> no reinstall, no data loss. Tested on Ubuntu 22.04 Server in VMware.
> Route used: **long-press Shift at boot → GRUB → recovery mode → root shell.**

---

## When to use this

- You can't log in (wrong/forgotten password, or an invisible-typing / keyboard-layout
  mix-up made the password not what you thought).
- You have console access to the machine (or the VM window).
- The account is a **local** account on this machine.

This does **not** erase anything — it only changes one user's password.

---

## Why logins fail even with the "right" password

Three common traps, all of which this method sidesteps:

- **Invisible password field** — Linux shows nothing as you type (no dots/stars). Easy to
  mistype without noticing.
- **Caps Lock** — the server console has no on-screen indicator; only the laptop's
  physical Caps Lock LED tells you.
- **Keyboard layout mismatch** — if the install used a different layout, symbols like
  `@ " / -` can land on different keys, so a password with special characters may not
  type the way you expect.

Tip that reveals these instantly: at the `login:` prompt, type your **password** on the
*username* line and press Enter. It fails, but usernames are visible — so you see exactly
which characters actually came out.

---

## Step-by-step

### 1. Open the GRUB boot menu
Reboot the machine. As it starts, **press and hold `Shift`** (BIOS boot) — or tap `Esc`
repeatedly (UEFI boot) — until the **GRUB** menu appears.

> In a VMware VM: click into the VM window first so it captures your keystrokes, then
> hold Shift as it boots. If you miss it, just restart and try again.

### 2. Enter recovery mode
- Select **"Advanced options for Ubuntu"** → press Enter.
- Choose the entry ending in **"(recovery mode)"** → press Enter.

### 3. Drop to a root shell
In the **Recovery Menu**, select **`root  —  Drop to root shell prompt`** and press Enter.
You'll get a prompt like:
```
root@hostname:~#
```

### 4. Make the filesystem writable
Recovery mode mounts the disk **read-only**, so remount it read-write first:
```bash
mount -o remount,rw /
```
(No output = success.)

### 5. Reset the password
Replace `USERNAME` with your actual account name (case-sensitive!):
```bash
passwd USERNAME
```
Enter the new password twice when prompted (invisible as you type).

> **Choose a simple temporary password** — lowercase letters/numbers only, e.g.
> `wazuh123` — to avoid re-triggering the Caps Lock / layout problem. You can change it
> later once you're safely logged in. If it warns the password is weak or dictionary-based,
> ignore the warning; it still sets it.

Success looks like:
```
passwd: password updated successfully
```

### 6. Boot normally
```bash
exit
```
Back in the Recovery Menu, select **`resume  —  Resume normal boot`** and press Enter.
At the login prompt, sign in with your username and the **new** password.

---

## If the username itself is uncertain
At the root shell, list the real login accounts before running `passwd`:
```bash
ls /home
# or, more precisely:
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd
```
Use the exact name shown (Linux is case-sensitive: `mercie` ≠ `Mercie`).

---

## Hardening note (optional, real-world)
This method works because physical/console access to a machine allows password reset —
which is expected for an owner, but also why **physical access = full access** in security
terms. On real production servers this is mitigated with **full-disk encryption (LUKS)**
and/or a **GRUB password**. For an isolated lab VM, neither is necessary — but it's worth
knowing *why* the reset was so easy: it's a property of console access, not a flaw.

---

*Personal lab notes — kept so a lockout is a 5-minute fix, not a reinstall.*