# Subdomain Recon Toolchain

Notes from setting up and running a passive subdomain enumeration and live-host
pipeline against a target domain, including the install issues hit along the
way and how each was fixed.

## Pipeline overview

1. **Enumerate subdomains** from multiple passive sources (subfinder, amass,
   assetfinder, crt.sh) and merge/dedupe the results.
2. **Resolve DNS** on the merged list with `dnsx` to drop anything with no
   record at all.
3. **Confirm live web hosts** with `httpx`, which also grabs status codes,
   page titles, and detected tech.
4. **Check for WAFs/firewalls** on the live hosts with `wafw00f` and
   `whatweb`.

```
subfinder ┐
amass     ├─► merge/dedupe ─► dnsx (resolve) ─► httpx (confirm live) ─► wafw00f / whatweb
assetfinder┤
crt.sh    ┘
```

## Tools and setup notes

### subfinder
Already installed in this environment; ran without issue.

```bash
subfinder -d target.com -all -o subfinder.txt
```

### amass
Not installed by default. Not in the standard apt repos in a current
version — use snap or build from source with Go.

```bash
sudo snap install amass
# fallback:
go install -v github.com/owasp-amass/amass/v4/...@master

amass enum -passive -d target.com -o amass.txt
```

### assetfinder
Go tool, not available via apt. Install with `go install`, then make sure
`~/go/bin` is on your `PATH` — Go doesn't add it automatically.

```bash
go install github.com/tomnomnom/assetfinder@latest
export PATH=$PATH:~/go/bin   # add to ~/.bashrc to persist

assetfinder --subs-only target.com > assetfinder.txt
```

### crt.sh (via curl + jq)
Pulls subdomains straight from certificate transparency logs. crt.sh's
servers are known to be slow/flaky, so a `jq: parse error` here usually means
the response wasn't valid JSON (rate-limited or an HTML error page), not a
mistake in the command.

```bash
curl -s -A "Mozilla/5.0" "https://crt.sh/?q=%25.target.com&output=json" \
  | jq -r '.[].name_value' | sort -u > crtsh.txt
```

If it keeps failing, it's fine to drop — subfinder + amass already give solid
coverage on their own.

### Merge and dedupe
```bash
cat subfinder.txt amass.txt assetfinder.txt crtsh.txt | sort -u > all_subdomains.txt
```

### dnsx
ProjectDiscovery Go tool — not in apt (apt's command-not-found helper will
suggest unrelated packages like `dnss` or `dnsq`; ignore those).

```bash
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest

dnsx -l all_subdomains.txt -resp -o resolved.txt
```

### httpx
Also a ProjectDiscovery Go tool. Note there's an unrelated Python HTTP client
library with the same name — if results look wrong, run `which httpx` to
confirm you're calling the right binary.

```bash
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

httpx -l resolved.txt -status-code -title -tech-detect -o live_hosts.txt
```

If `live_hosts.txt` comes back empty, check upstream first — an empty or
tiny `resolved.txt` from the dnsx step is the usual cause, not httpx itself.

### wafw00f
Purpose-built WAF fingerprinting tool. Available via apt in most cases —
if `command not found` appears with a suggested apt package, just run the
install.

```bash
sudo apt update && sudo apt install wafw00f
# fallback if apt doesn't have it:
pip install wafw00f --break-system-packages

wafw00f -i live_hosts.txt -o waf_results.txt
```

### whatweb
Second opinion on WAF/CDN/tech-stack detection, to catch anything wafw00f
misses. Same install pattern as wafw00f.

```bash
whatweb -i live_hosts.txt --log-json=whatweb_results.json
```

## Troubleshooting quick reference

| Tool | Symptom | Fix |
|---|---|---|
| amass | `command not found` | `sudo snap install amass` |
| assetfinder | `command not found` | `go install ...assetfinder@latest` + fix PATH |
| crt.sh/jq | `jq: parse error` | Add `-A "Mozilla/5.0"`, retry, or skip |
| dnsx | `command not found`, wrong apt suggestions | `go install ...dnsx/cmd/dnsx@latest` |
| httpx | Confused with Python `httpx` package | `which httpx` to confirm binary source |
| wafw00f | `command not found` | `sudo apt install wafw00f` |

## Where this is useful

- **A personal runbook** for rebuilding this toolchain on a new machine or VM
  without re-discovering the same install issues each time.
- **Documentation for a class assignment or lab writeup**, showing not just
  final output but the actual process and how problems were diagnosed —
  which is usually what's being graded.
- **A living methodology doc** to reuse across engagements: the pipeline
  structure (enumerate → resolve → confirm live → fingerprint) applies to any
  target, only the domain changes.
- **Team onboarding**, if others need to set up the same recon environment —
  this doubles as a known-issues list so teammates don't hit the same errors
  from scratch.
- **A GitHub portfolio piece** demonstrating recon methodology and tool
  familiarity for security/pentesting work, without needing to expose actual
  scan results against a real target.