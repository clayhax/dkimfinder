#!/bin/bash

# Green color for selector
green=$'\033[0;32m'
nc=$'\033[0m'

print_banner() {
  if command -v figlet >/dev/null 2>&1; then
    mapfile -t left < <(figlet -f small "dkim")
    mapfile -t right < <(figlet -f small "finder")

    for i in "${!left[@]}"; do
      printf '%b%s%b%s\n' "$green" "${left[$i]}" "$nc" "${right[$i]}"
    done

    printf '\n          %bv1.1%b by clayhax\n\n' "$green" "$nc"
  else
    printf '%b\n' \
"${green}    _ _    _            ${nc}__ _           _
${green} __| | | _(_)_ __ ___ ${nc}/ _(_)_ __   __| | ___ _ __
${green}/ _\` | |/ / | '_ \` _ \\${nc}| |_| | '_ \\ / _\` |/ _ \\ '__|
${green}| (_| |   <| | | | | | |${nc}  _| | | | | (_| |  __/ |
${green} \\__,_|_|\\_\\_|_| |_| |_|${nc}_| |_|_| |_|\\__,_|\\___|_|

          ${green}v1.1${nc} by clayhax"
  fi
}

if [ -z "$1" ]; then
  print_banner
  echo "Usage: $0 domain.com"
  exit 1
fi

domain="$1"
print_banner
selector_file="selectors.txt"
output_file="valid-selectors-${domain//./-}.txt"
temp_dir=$(mktemp -d -t dkimcheck-XXXXXXXX)
total=$(wc -l < "$selector_file")
count=0

echo -e "\nValid DKIM selectors for $domain:"
echo "-----------------------------------"

# Export vars for parallel environment
export domain temp_dir green nc

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

  if echo "$full_record" | grep -Eq '^(v=DKIM1|k=rsa|.*p=)' ; then
    echo -e "${fqdn} | ${full_record}\n" > "$temp_dir/$selector.dkim"
    echo -e "\n${green}${selector}${nc}._domainkey.${domain} | ${full_record}"
  fi
}

export -f scan_selector

# Parallel execution
{
  while read -r selector; do
    echo "$selector"
  done < "$selector_file"
} | xargs -P 20 -I{} bash -c 'scan_selector "$@"' _ {}

# Combine and report
if compgen -G "$temp_dir/*.dkim" > /dev/null; then
  cat "$temp_dir"/*.dkim > "$output_file"
  echo -e "\nResults saved to $output_file"
else
  echo -e "\nNo DKIM records found for $domain"
fi

rm -rf "$temp_dir"
