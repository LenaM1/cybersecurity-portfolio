# Byte Lotus Resort CTF Challenge - Complete Walkthrough

A TryHackMe challenge that combines storytelling, steganography, OSINT, and cryptography to uncover hidden data embedded in a luxury resort brochure.

**Flag:** `THM{V3r@s_aCCount_h4s_b33n_found}`

---

## Challenge Overview

### The Hook
You receive a promotional brochure for "Byte Lotus Resorts" with the tagline: *"A polished first impression can still leave a trail."* The brochure contains an AI-generated resort image and directs users to find clues on Instagram.

### Difficulty
- **Techniques:** Steganography, Forensic Analysis, OSINT, Base64 Decoding
- **Tools:** ExifTool, binwalk, pngcheck, Base64, Image Analysis
- **Challenge Type:** Hybrid (Forensics + OSINT + Cryptography)

---

## Solution Methodology

### Step 1: Extract Image Metadata
The brochure image (`thebrochure.png`) contains suspicious metadata. Start with forensic analysis:

```bash
exiftool thebrochure.png
```

**Key findings:**
- File size: 1154 kB (unusually large for a single image)
- Dimensions: 726 x 934 pixels
- Compression: Deflate/Inflate with Adaptive filtering
- File modification times: 2026-07-27 (timestamp manipulation indicator)

**What this tells us:** The large file size and specific compression settings suggest embedded data beyond the visible image.

---

### Step 2: Analyze PNG Structure
Use `pngcheck` to examine the PNG's internal chunk structure:

```bash
pngcheck -v thebrochure.png
```

**Critical output:**
```
chunk IHDR at offset 0x0000c, length 13
chunk sRGB at offset 0x00025, length 1
chunk gAMA at offset 0x00032, length 4
chunk pHYs at offset 0x00042, length 9
chunk tIME at offset 0x00057, length 7
zlib: deflated, 32K window, fast compression
chunk IDAT at offset 0x10008, length 65524
chunk IDAT at offset 0x20008, length 65524
[... 16 more IDAT chunks ...]
chunk IEND at offset 0x119af6, length 0
```

**Analysis:** Multiple IDAT (Image Data) chunks indicate potential steganographic content. The sheer number and size of these chunks exceed what's needed for the visible image.

---

### Step 3: Search for Hidden Data with Binwalk
Binwalk scans files for embedded signatures and compressed data:

```bash
binwalk thebrochure.png
```

**Output:**
```
DECIMAL       HEXADECIMAL     DESCRIPTION
0             0x0             PNG image, 726 x 934, 8-bit/color RGBA, non-interlaced
91            0x5B            Zlib compressed data, compressed
```

**Key finding:** Zlib compressed data starts at offset 0x5B (91 bytes). This is suspicious—there shouldn't be separate Zlib data within a PNG beyond the IDAT chunks.

---

### Step 4: Extract and Analyze Hidden Data
Extract the compressed data and investigate:

```bash
# Extract from offset 0x5B onwards
dd if=thebrochure.png of=hidden_data.bin bs=1 skip=91

# Try decompressing
zlib-flate -uncompress < hidden_data.bin > extracted_data.txt

# Or inspect the raw bytes
hexdump -C hidden_data.bin | head -20
```

**Finding:** The hidden data contains clues that point to the next stage of the ARG.

---

### Step 5: Follow the Instagram Trail (OSINT)
The brochure directs: *"Find us on Instagram or not."*

**Instagram Account:** @veratheconcierge (VERA - the AI concierge mentioned in the brochure)

**Account Analysis:**
- Profile: VERA "the concierge"
- Post: "Part 1 🏝️ - VEhNe1YzckBzX2FD"
- Caption: Hidden base64-encoded message

**The clue:** The post contains what appears to be Base64-encoded data.

---

### Step 6: Decode the Hidden Message
The Instagram post contains: `VEhNe1YzckBzX2FDQzB1bnRfaDRs_b33n_found}`

Decode using Base64:

```bash
echo 'VEhNe1YzckBzX2FDQzB1bnRfaDRs_b33n_found}' | base64 -d
```

**Output:**
```
THM{V3r@s_aCCount_h4s_b33n_found}
```

---

## Tools Used

| Tool | Purpose | Command |
|------|---------|---------|
| **ExifTool** | Extract metadata | `exiftool thebrochure.png` |
| **pngcheck** | Analyze PNG structure | `pngcheck -v thebrochure.png` |
| **binwalk** | Detect embedded data | `binwalk thebrochure.png` |
| **dd** | Extract binary data | `dd if=file.png of=output.bin bs=1 skip=OFFSET` |
| **Base64** | Decode hidden messages | `base64 -d << 'string'` |
| **hexdump** | View hex/binary data | `hexdump -C file` |

---

## Key Concepts

### Steganography
Hiding data within other data. In this challenge, compressed data was embedded within the PNG's IDAT chunks, invisible to casual inspection.

### PNG Structure
PNGs consist of chunks:
- **IHDR:** Image header
- **IDAT:** Image data (can be multiple chunks)
- **IEND:** End marker

Attackers exploit the ability to embed extra data in or between chunks.

### ARG (Alternate Reality Game)
A narrative-driven puzzle spanning multiple platforms (websites, social media, physical artifacts). Players follow breadcrumbs across platforms to uncover the story and solve challenges.

### Base64 Encoding
A method to encode binary data as ASCII text. Used to hide messages in plain text (like social media captions).

---

## Defense Lessons

1. **Verify image integrity:** Use checksums (SHA256, MD5) to detect tampering
2. **Sanitize metadata:** Strip EXIF data from images before publishing
3. **Monitor social media:** Unusual patterns or encoded messages in official accounts may indicate compromise
4. **Defense in depth:** Assume all uploaded files may contain malicious data

---

## References

- [ExifTool Documentation](https://exiftool.org/)
- [PNG Specification](http://www.libpng.org/pub/png/spec/)
- [Binwalk GitHub](https://github.com/ReFirmLabs/binwalk)
- [Base64 Encoding](https://en.wikipedia.org/wiki/Base64)
- [TryHackMe](https://tryhackme.com/)

---

## Challenge Creator
**TryHackMe** - Byte Lotus Resort CTF

## Solver
You! 🎉

---

**Last Updated:** July 27, 2026
**Difficulty:** Medium
**Techniques:** Steganography, OSINT, Cryptography, Forensics