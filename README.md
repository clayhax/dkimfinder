# dkimfinder

A fast, parallelized Bash tool for discovering valid DKIM selectors for a given domain.

Built for security professionals, pentesters, and OSINT workflows to quickly enumerate and validate DKIM records at scale.

---

## Features

* Scans a list of common DKIM selectors against a target domain
* Parallelized lookups for speed (uses `xargs -P`)
* Automatically detects valid DKIM records (`v=DKIM1`, `p=`)
* Handles CNAME-based DKIM configurations
* Clean CLI output with color + ASCII banner
* Saves valid results to file

---

## Requirements

* Bash
* `dig` (DNS utilities)
* `xargs`
* *(optional)* `figlet` for banner styling

Install dependencies (Debian/Kali):

```bash
sudo apt install dnsutils figlet -y
```

---

## Usage

```bash
./dkimfinder.sh domain.com
```

---

## Input

The tool expects a file in the same directory named:

```bash
selectors.txt
```

This should contain a list of DKIM selectors (one per line), for example:

```
default
selector1
selector2
google
k1
s1
```

---

## Output

Valid DKIM selectors are printed to the terminal and saved to:

```bash
valid-selectors-domain-com.txt
```

Example output:

```
selector1._domainkey.example.com | v=DKIM1; k=rsa; p=MIIBIjANBgkq...
```

---

## How It Works

For each selector:

1. Queries:

   ```
   selector._domainkey.domain.com
   ```

2. Checks for:

   * CNAME → resolves to target
   * TXT record → extracts full DKIM key

3. Validates presence of:

   * `v=DKIM1`
   * `p=` (public key)

---

## Performance

* Uses parallel DNS resolution (`xargs -P`)
* Default concurrency: **20 threads**

---

## Customization

* Modify `selectors.txt` to expand coverage

---

## Author

clayhax

---

Comments, suggestions, and improvements are always welcome. Be sure to follow @0xclayhax on Twitter for the latest updates.
