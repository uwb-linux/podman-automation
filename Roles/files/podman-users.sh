#!/bin/bash

GROUP="css-podman"
BASE_UID=100000
RANGE_SIZE=65536

users=$(getent group "$GROUP" | awk -F: '{print $4}' | tr ',' ' ')
if [ -z "$users" ]; then
  echo "No users found in group $GROUP"
  exit 1
fi

# Collect all already-assigned ranges
used_ranges=()
parse_ranges() {
  awk -F: '{print $2":"$3}' "$1" | while IFS=: read start count; do
    used_ranges+=("${start}:${count}")
  done
}

parse_ranges /etc/subuid

next_uid=$BASE_UID

find_next_free() {
  local candidate=$1
  while :; do
    local overlap=0
    for range in "${used_ranges[@]}"; do
      local start=${range%%:*}
      local count=${range##*:}
      local end=$((start + count - 1))
      local candidate_end=$((candidate + RANGE_SIZE -1))
      # If candidate overlaps
      if ! ((candidate > end || candidate_end < start)); then
        candidate=$((end+1))
        overlap=1
        break
      fi
    done
    [ "$overlap" = "0" ] && break
  done
  echo "$candidate"
}

for user in $users; do
  user=${user%% *}  # Trim whitespace
  if [ -z "$user" ]; then continue; fi

  if grep -Eq "^$user:" /etc/subuid; then
    echo "$user already has a subuid allocation, skipping"
    continue
  fi

  uid=$(find_next_free $next_uid)
  sudo usermod --add-subuids ${uid}-$((uid+RANGE_SIZE-1)) "$user"
  sudo usermod --add-subgids ${uid}-$((uid+RANGE_SIZE-1)) "$user"
  echo "Assigned $user: $uid-$((uid+RANGE_SIZE-1))"
  used_ranges+=("${uid}:${RANGE_SIZE}")
  next_uid=$((uid+RANGE_SIZE))
done

echo "Done! Check /etc/subuid and /etc/subgid for results."
