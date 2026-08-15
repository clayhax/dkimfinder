#!/bin/bash

# dkimfinder v1.1 by cl4yh4x

# Green color
green=$'\033[0;32m'
nc=$'\033[0m'

selector_file="selectors.txt"
show_banner=true

print_banner() {
    [[ "$show_banner" == false ]] && return
    if command -v figlet >/dev/null 2>&1; then
    mapfile -t left < <(figlet -f small "dkim")
    mapfile -t right < <(figlet -f small "finder")

    for i in "${!left[@]}"; do
      printf '%b%s%b%s\n' "$green" "${left[$i]}" "$nc" "${right[$i]}"
    done

    printf '\n          %bv1.1%b by cl4yh4x\n\n' "$green" "$nc"
  else
    printf '%b\n' \
"${green}    _ _    _            ${nc}__ _           _
${green} __| | | _(_)_ __ ___ ${nc}/ _(_)_ __   __| | ___ _ __
${green}/ _\` | |/ / | '_ \` _ \\${nc}| |_| | '_ \\ / _\` |/ _ \\ '__|
${green}| (_| |   <| | | | | | |${nc}  _| | | | | (_| |  __/ |
${green} \\__,_|_|\\_\\_|_| |_| |_|${nc}_| |_|_| |_|\\__,_|\\___|_|

          ${green}v1.1${nc} by cl4yh4x"
  fi
}

usage() {
  print_banner

  echo "Usage:"
  echo "  $0 domain.com"
  echo "  $0 domain1.com domain2.com domain3.com"
  echo "  $0 domain1.com,domain2.com,domain3.com"
  echo "  $0 -d FILE  Read target domains from FILE"
  echo "  --no-banner Suppress the ASCII banner"
  exit 1
}

# Function to scan one selector
scan_selector() {
  local selector="$1"
  local fqdn="${selector}._domainkey.${domain}"
  local cname full_record

  cname=$(dig +short CNAME "$fqdn")

  if [[ -n "$cname" ]]; then
    full_record=$(dig TXT "$cname" +short | tr -d '"' | paste -sd '' -)
  else
    full_record=$(dig TXT "$fqdn" +short | tr -d '"' | paste -sd '' -)
  fi

  if echo "$full_record" | grep -Eq '^(v=DKIM1|k=rsa|.*p=)'; then
    echo -e "${fqdn} | ${full_record}\n" > "$temp_dir/$selector.dkim"
    echo -e "\n${green}${selector}${nc}._domainkey.${domain} | ${full_record}"
  fi
}

export -f scan_selector
export green nc

# helper
valid_domain() {
  local d="$1"

  # Reject empty values and anything that looks like an option
  [[ -n "$d" ]] || return 1
  [[ "$d" != -* ]] || return 1

  # Basic hostname/domain validation
  [[ "$d" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

# Scan a single domain
scan_domain() {
  domain="$1"
  output_file="valid-selectors-${domain//./-}.txt"
  temp_dir=$(mktemp -d -t dkimcheck-XXXXXXXX)

  export domain temp_dir

  echo
  echo "Valid DKIM selectors for $domain:"
  echo "-----------------------------------"

  while read -r selector; do
    [[ -z "$selector" ]] && continue
    [[ "$selector" =~ ^[[:space:]]*# ]] && continue
    echo "$selector"
  done < "$selector_file" |
    xargs -r -P 20 -I{} bash -c 'scan_selector "$@"' _ {}

  if compgen -G "$temp_dir/*.dkim" > /dev/null; then
    cat "$temp_dir"/*.dkim > "$output_file"
    echo -e "\nResults saved to $output_file"
  else
    echo -e "\nNo DKIM records found for $domain"
  fi

  rm -rf "$temp_dir"
}

args=()

for arg in "$@"; do
  case "$arg" in
    --no-banner)
      show_banner=false
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

set -- "${args[@]}"

case "${1:-}" in
  -h|--help)
    usage
    ;;
esac

# Check dependencies
if ! command -v dig >/dev/null 2>&1; then
  echo "Error: dig is required but was not found."
  echo "Install it with: sudo apt install dnsutils"
  exit 1
fi

# Check selector file
if [[ ! -f "$selector_file" ]]; then
  echo "Error: $selector_file not found."
  exit 1
fi

# No arguments
if [[ $# -eq 0 ]]; then
  usage
fi

domains=()

# Domain list mode
if [[ "$1" == "-d" ]]; then

  if [[ -z "${2:-}" ]]; then
    echo "Error: -d requires a domain list."
    echo
    usage
  fi

  domain_file="$2"

  if [[ ! -f "$domain_file" ]]; then
    echo "Error: Domain file '$domain_file' not found."
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Remove comments
    line="${line%%#*}"

    # Support comma-separated entries inside the file too
    line="${line//,/ }"

    for entry in $line; do
      [[ -n "$entry" ]] && domains+=("$entry")
    done
  done < "$domain_file"

else

  # Positional domain arguments
  # Supports either spaces or commas
  for arg in "$@"; do
    IFS=',' read -ra entries <<< "$arg"

    for entry in "${entries[@]}"; do
      entry="${entry#"${entry%%[![:space:]]*}"}"
      entry="${entry%"${entry##*[![:space:]]}"}"

      [[ -n "$entry" ]] && domains+=("$entry")
    done
  done

fi

if [[ ${#domains[@]} -eq 0 ]]; then
  echo "Error: No domains supplied."
  exit 1
fi

# Validate all domains before beginning scan
for domain in "${domains[@]}"; do
  if ! valid_domain "$domain"; then
    echo "Error: Invalid domain: $domain" >&2
    echo "Use -h or --help for usage." >&2
    exit 1
  fi
done

print_banner

echo "Domains queued: ${#domains[@]}"

for domain in "${domains[@]}"; do
  scan_domain "$domain"
done
