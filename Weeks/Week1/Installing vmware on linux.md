# Installing VMware Workstation Pro on Linux

> **Last Updated:** July 2026

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Getting the Free VMware Workstation Pro Download](#getting-the-free-vmware-workstation-pro-download)
4. [Installing VMware Workstation Pro](#installing-vmware-workstation-pro)
5. [Launching VMware](#launching-vmware)
6. [Installing Required Kernel Modules](#installing-required-kernel-modules)
7. [Common Troubleshooting](#common-troubleshooting)
8. [Uninstalling VMware](#uninstalling-vmware)

---

# Overview

VMware Workstation Pro is a desktop virtualization platform that allows you to run multiple operating systems on a Linux host.

As of recent VMware releases, **VMware Workstation Pro is available at no cost**. The software is distributed through Broadcom's Support Portal, and no license key is required for the free version. During installation you simply choose the free usage option if prompted. :contentReference[oaicite:0]{index=0}

---

# Prerequisites

Before installing VMware, ensure your system has:

- A 64-bit Linux distribution
- Hardware virtualization enabled (Intel VT-x or AMD-V)
- At least:
  - 4 GB RAM (8 GB+ recommended)
  - 20 GB free disk space
- Root or sudo privileges
- Kernel headers installed

For Debian/Ubuntu:

```bash
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r)
```

For Fedora:

```bash
sudo dnf install kernel-devel kernel-headers gcc make
```

For Arch Linux:

```bash
sudo pacman -S base-devel linux-headers
```

---

# Getting the Free VMware Workstation Pro Download

## Step 1 – Create a Broadcom Account

Open:

https://support.broadcom.com

Click **Register** if you do not already have an account.

You may be asked to:

- Verify your email
- Complete your profile
- Provide your address
- Complete an export compliance form

Use accurate information to avoid account verification delays. :contentReference[oaicite:1]{index=1}

---

## Step 2 – Sign In

Log in to the Broadcom Support Portal.

---

## Step 3 – Navigate to Downloads

After signing in:

1. Open the **Software** section (or VMware products section, depending on the portal layout).
2. Choose **VMware Cloud Foundation**.
3. Select **My Downloads**.
4. Search for:

```
VMware Workstation Pro
```

5. Select:

```
VMware Workstation Pro
```

6. Choose the latest Linux release.

Community users note that searching from **My Downloads** is often the quickest way to find the installer if the portal layout changes. :contentReference[oaicite:2]{index=2}

---

## Step 4 – Accept the Terms

Check:

- **I agree to the Terms and Conditions**

If prompted:

- Complete the Trade Compliance verification.

---

## Step 5 – Download the Linux Installer

Download the Linux bundle file, for example:

```
VMware-Workstation-Full-*.x.x-xxxxxxx.x86_64.bundle
```

---

# Installing VMware Workstation Pro

Navigate to the download directory:

```bash
cd ~/Downloads
```

Make the installer executable:

```bash
chmod +x VMware-Workstation-Full-*.bundle
```

Run the installer:

```bash
sudo ./VMware-Workstation-Full-*.bundle
```

Follow the graphical installer.

If asked about licensing:

- Select the **free** option (no license key required for supported free versions). :contentReference[oaicite:3]{index=3}

---

# Launching VMware

From your desktop launcher:

```
Applications → VMware Workstation Pro
```

or from the terminal:

```bash
vmware
```

The first launch may compile kernel modules.

This may take several minutes.

---

# Installing Required Kernel Modules

If VMware asks to build modules:

Choose:

```
Install
```

or

```
Compile
```

If compilation fails, verify that:

- gcc is installed
- make is installed
- kernel headers match your running kernel

Ubuntu:

```bash
sudo apt install build-essential linux-headers-$(uname -r)
```

Fedora:

```bash
sudo dnf install kernel-devel kernel-headers gcc make
```

Reboot if the kernel was updated.

---

# Common Troubleshooting

## VMware will not start

Try:

```bash
vmware
```

from a terminal to view error messages.

---

## Kernel module compilation failed

Verify:

```bash
uname -r
```

matches the installed kernel headers.

Install missing headers and rerun VMware.

---

## Secure Boot Enabled

Secure Boot may prevent VMware kernel modules from loading.

Options include:

- Disable Secure Boot in BIOS/UEFI, or
- Sign VMware kernel modules for Secure Boot.

---

## Permission Denied

Ensure the installer is executable:

```bash
chmod +x VMware-Workstation-Full-*.bundle
```

---

# Uninstalling VMware

Run:

```bash
sudo vmware-installer -u vmware-workstation
```

or

```bash
sudo vmware-installer
```

and choose **Uninstall**.

---

# Additional Notes

- The free version does **not** require a license key for current supported releases.
- A Broadcom account is required to download the installer.
- Older VMware Workstation releases may still require a commercial license and may not be available to free users. :contentReference[oaicite:4]{index=4}