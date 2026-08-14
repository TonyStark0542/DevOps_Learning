# trace-request

A bash script that walks a domain through every network layer a browser touches — DNS, routing, TCP, TLS, and HTTP — in one command. I built this after manually running each layer's diagnostic tool by hand (`dig`, `traceroute`, `openssl s_client`, `curl`) to understand what a browser actually does before a page loads, then automated the whole sequence.

## What it does

- **Resolves the domain** — shows the resolved IP, record type, and TTL
- **Tests the network path** — ping reachability + a traceroute of the first hops
- **Checks TCP reachability on ports 80 and 443** — and distinguishes *refused* (something answered and said no) from *timeout* (nothing answered at all) based on response timing
- **Reports the TLS certificate** — subject, issuer, and days until expiry, flagging anything expiring within 14 days
- **Fetches HTTP headers on both `http://` and `https://`** — reports the status code, grouped by family (2xx/3xx/4xx/5xx), and shows the `Location` header on redirects
- **Fails loudly and early** if a required command (`dig`, `curl`, `openssl`) isn't installed, instead of dying mid-run with a bare "command not found"

## How to run it

```bash
chmod +x trace_request.sh
./trace_request.sh example.com
```

Requires `dig`, `curl`, and `openssl`. `ping`, `traceroute`, and `nc` are optional — their sections skip cleanly with a warning if missing.

```bash
# Ubuntu/Debian, if you need them:
sudo apt install dnsutils curl openssl iputils-ping traceroute netcat-openbsd
```

## Sample output

```
Tracing: github.com

== 1. DNS resolution ==
  ✓ github.com. -> 20.207.73.82  (type A, TTL 56s = 0m 56s remaining before this is re-checked)

== 2. Network path ==
  ✓ ping reachable — 0% packet loss
  Route (first 8 hops):
     1  reliance.reliance (192.168.29.1)  5.893 ms  5.853 ms  5.832 ms
     2  10.7.0.1 (10.7.0.1)  6.794 ms  6.775 ms  6.887 ms
     3  172.16.5.8 (172.16.5.8)  8.661 ms  8.642 ms 172.16.5.10 (172.16.5.10)  8.624 ms
     4  192.168.247.204 (192.168.247.204)  8.606 ms 192.168.247.200 (192.168.247.200)  7.181 ms  8.551 ms
     5  192.168.230.214 (192.168.230.214)  6.755 ms  8.603 ms  11.071 ms
     6  192.168.230.194 (192.168.230.194)  11.435 ms  6.883 ms 192.168.230.195 (192.168.230.195)  6.828 ms
     7  192.168.59.114 (192.168.59.114)  6.809 ms 192.168.59.110 (192.168.59.110)  5.362 ms 192.168.59.112 (192.168.59.112)  5.232 ms
     8  * * *

== 3. TCP reachability (ports 80 / 443) ==
  ✓ port 80 open (connected in 119ms)
  ✓ port 443 open (connected in 115ms)

== 4. TLS certificate ==
  ✓ Subject : CN=github.com
  ✓ Issuer  : C=GB, O=Sectigo Limited, CN=Sectigo Public Server Authentication CA DV E36
  ✓ Valid   : Jul  3 00:00:00 2026 GMT  ->  Sep 30 23:59:59 2026 GMT
  ✓ Certificate expires in 47 day(s)

== 5. HTTP response ==
  ✓ https://github.com -> 200
  ! http://github.com -> 301 (redirect) Location: https://github.com/

== Done ==
Traced github.com through DNS, routing, TCP, TLS, and HTTP.
```

## Methodology

I didn't write this script from a spec — I ran each layer by hand first, against a real domain, and only automated it once I understood what each command was actually proving:

1. **DNS** — `dig +trace` to watch the resolver walk root → TLD → authoritative server, then `dig +short` for the fast path the script uses.
2. **Routing** — `ping` and `traceroute` to see the path, and to understand that ICMP being blocked (common on cloud hosts) isn't the same as the host being down.
3. **TCP** — captured the literal three-way handshake with `tcpdump` while curling the target in a second terminal, and watched `SYN` → `SYN-ACK` → `ACK` appear as real packets. The script's port check (`nc -z`) is a scripted version of that same handshake, timed to distinguish an active refusal (fast) from a silent drop (slow, hits the timeout).
4. **TLS** — `openssl s_client` to read the full certificate chain and understand what a cert actually proves (identity, not safety) and how the chain of trust resolves back to a root CA.
5. **HTTP** — `curl -v` to watch the request/response exchange, and to connect status code families back to real debugging value — e.g. the difference between a 502 (bad upstream response) and a 504 (upstream too slow) tells you where to look first when something's broken.

Every check in the script traces back to one of these manual runs — nothing here is guessed.
