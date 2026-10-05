# crAPI Vulnerability Assessment — In Progress

**Target:** OWASP crAPI (github.com/OWASP/crAPI)
**Date started:** September 22, 2026
**Status:** 🟡 Ongoing — 1 confirmed finding, several vectors still open

---

## 1. Environment

| Component | Details |
|---|---|
| crAPI host | Dedicated Ubuntu Desktop VM, IP `192.168.92.133`, isolated on same VMware NAT subnet as existing lab (`192.168.92.0/24`) |
| Attacker host | Kali Linux, IP `192.168.92.128` (same as PtH scenario) |
| App URL | `http://192.168.92.133:8888` |
| MailHog (OTP/email capture) | `http://192.168.92.133:8025` |
| Proxy | Burp Suite Community Edition, listening `127.0.0.1:8080` |
| Deployment | Docker Compose, `--compatibility` mode, `LISTEN_IP="0.0.0.0"` override to expose beyond localhost |
| Backend services observed | `crapi-gateway`, `crapi-identity`, `crapi-community`, `crapi-workshop`, `crapi-chatbot`, `crapi-web`, `chromadb`, `mailhog`, `mongodb`, `postgresdb` |

**Setup note:** crAPI was deliberately run on its own VM rather than the host machine, to keep the vulnerable app fully isolated from the host's network — same architectural pattern as the DC01/Kali lab. One infra snag along the way: the Ubuntu Server LVM installer under-allocated the root logical volume (14GB used of a 28GB disk); resolved via `lvextend` + `resize2fs` before proceeding.

---

## 2. Methodology

1. Stood up crAPI via Docker Compose, confirmed all services healthy
2. Confirmed cross-VM reachability from Kali (`curl -I` → `200 OK`)
3. Walked the intended "happy path" (signup → email verification via MailHog → login → add vehicle via VIN/PIN → explored Shop) while passively logging all traffic through Burp Suite (Proxy → HTTP History)
4. Cross-referenced discovered endpoints against OWASP's official crAPI challenge list (`docs/challenges.md`) to confirm which vulnerability classes were being targeted, rather than testing blind

---

## 3. Confirmed Finding #1 — NoSQL Injection in Coupon Validation

**Maps to:** Official crAPI Challenge 12 — *"Find a way to get free coupons without knowing the coupon code."*
**OWASP API Security Top 10 category:** Injection / Security Misconfiguration (unsanitized input passed directly into a MongoDB query)

### Endpoint
```
POST /community/api/v2/coupon/validate-coupon
```
Backed by the `crapi-community` service, which is backed by MongoDB (confirmed via `docker compose ps` and consistent with the NoSQL injection challenge category).

### Root cause
The `coupon_code` field is passed unsanitized into a MongoDB query. Because MongoDB queries accept JSON objects with query operators, submitting an **object** instead of a plain string lets an attacker inject a Mongo operator directly, bypassing the intended "does this exact string match a real coupon" check.

### Proof of Concept

**Baseline test** — confirmed the endpoint and normal rejection behavior:
```json
POST /community/api/v2/coupon/validate-coupon
{"coupon_code": "TEST123"}
```
→ `500 Internal Server Error`, empty body `{}`

*(Side finding: the 500-with-empty-body on a plainly invalid string is itself a minor issue — improper error handling / potential info disclosure risk, since a well-formed API should return a clean `400` with a descriptive error instead of an unhandled exception. Also revealed the backend is Go-based, via the wording of a later JSON parse error: `"invalid character '{' looking for beginning of object key string"` — that phrasing is characteristic of Go's `encoding/json` package.)*

**Exploit payload:**
```json
POST /community/api/v2/coupon/validate-coupon
{
    "coupon_code": {"$ne": "null"}
}
```

**Result:**
```json
HTTP/1.1 200 OK
{
    "coupon_code": "TRAC075",
    "amount": "75",
    "CreatedAt": "2026-09-22T18:36:05.788Z"
}
```

The `$ne` ("not equal") MongoDB operator matched against whatever coupon existed in the collection, returning a fully valid, previously unknown coupon code worth **$75**, with zero prior knowledge of any real code required.

### Impact
An attacker can enumerate/leak valid coupon codes without brute-forcing or social engineering, with direct financial impact if the leaked coupon is redeemed (balance increase / free items in the Shop). Given the account started with a $100 balance, a $75 coupon represents a meaningful, attacker-controlled financial gain.

### Status
✅ Vulnerability confirmed and coupon code successfully leaked via injection.
🔲 **Not yet done:** actually redeeming `TRAC075` at checkout to demonstrate full financial impact (the official challenge framing implies this is the intended full exploit chain — "get free coupons," not just "see a coupon code").

---

## 4. Other Attack Surface Identified (Not Yet Tested)

Discovered during recon, not yet attacked — listed here to resume from:

| Area | Why it's promising | Likely OWASP category |
|---|---|---|
| **Vehicle add via VIN + PIN** (`POST /identity/api/v2/vehicle/add_vehicle`) | 4-digit numeric PIN (10,000 combinations); initial brute-force attempt against a guessed/invalid VIN returned flat `403` — inconclusive, needs a real seeded VIN to test properly | API4:2023 — Unrestricted Resource Consumption (no observed rate limiting on the endpoint itself) |
| **Vehicle location / details by VIN** | Classic BOLA candidate — swap VIN for another user's to see if authorization is enforced server-side, not just client-side | API1:2023 — Broken Object Level Authorization (this is literally Challenge 1 in OWASP's own list) |
| **Mechanic reports for other users** | Explicitly named in OWASP's challenge list as Challenge 2 | API1:2023 — BOLA |
| **Contact Mechanic** | Known in community writeups to be susceptible to SSRF | API7:2023 — Server-Side Request Forgery (Challenge 11 — forcing crAPI to make an HTTP call to `www.google.com` and return the response) |
| **Past Orders** | Sequential order IDs are a common BOLA vector; also tied to refund-abuse challenges (Challenge 9 — increase balance by $1,000+ via refund manipulation) | API1:2023 — BOLA / Business Logic |
| **JWT (Bearer token)** | Not yet decoded/analyzed. Known crAPI/community writeups reference `alg:none` and algorithm-confusion attacks against crAPI's JWT implementation | API2:2023 — Broken Authentication |
| **Chatbot widget** (`crapi-chatbot`, backed by `chromadb`) | Newer addition to crAPI; LLM-adjacent attack surface (prompt injection potential) not part of original 12 core challenges but worth probing given it's clearly deployed | Not in original OWASP API Top 10 challenge set — emerging AI-adjacent risk |
| **SQL injection via already-claimed coupon** | Official Challenge 13 — redeem a coupon already claimed, by manipulating the database | API3:2023 — Injection (SQL, distinct from the NoSQL finding above — likely a different code path, possibly in the `workshop` service given Postgres is present) |

---

## 5. Next Session Priorities

1. Redeem `TRAC075` to complete the coupon finding end-to-end
2. Decode and analyze the JWT (algorithm, claims, signature handling)
3. Test BOLA on vehicle details/location using a second test account, to directly replicate OWASP Challenge 1 with two accounts cross-testing each other's data
4. Revisit VIN/PIN brute-force with a confirmed-real VIN (need to find one — possibly visible via the BOLA test above, or seeded in a second account)
5. Attempt the SSRF challenge via Contact Mechanic
6. Explore Past Orders for BOLA + refund/balance manipulation (Challenges 8–9)

---

## 6. Tools Used
- Burp Suite Community Edition (Proxy, Repeater)
- Python 3 (`requests`) for scripted testing — used for the inconclusive VIN/PIN brute-force attempt
- MailHog for OTP/email interception
- OWASP's own `docs/challenges.md` as a directed-testing reference rather than pure black-box guessing