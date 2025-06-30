@@ -1,38 +1,68 @@
# /etc/profile.d/podman_lab.sh

# CONFIGURATION --- EDIT THESE AS NEEDED
lab_group="css-podman"
podman_basedir="/lab/podman-users"   # or /home if you want to use the normal homedir
base_uid=200000
map_size=65536

# Only run in interactive shells
[[ $- != *i* ]] && return

user=$(whoami)

# Only perform setup if user is in group and not root
if [ "$user" != "root" ] && id -nG "$user" | grep -qw "$lab_group"; then
  # Ensure Podman base directories
  if [ ! -d "$podman_basedir/$user" ]; then
    mkdir -p "$podman_basedir/$user/run"
    chown "$user:$user" "$podman_basedir/$user" "$podman_basedir/$user/run"
    chmod 700 "$podman_basedir/$user"
  fi
#!/bin/bash

  # Ensure unique subuid/subgid mappings
  if ! grep -q "^$user:" /etc/subuid; then
    last_uid=$(awk -F: '{ print $2 }' /etc/subuid | sort -n | tail -1)
    if [ -z "$last_uid" ]; then
      next_uid=$base_uid
    else
      next_uid=$((last_uid + map_size))
    fi
    echo "$user:$next_uid:$map_size" | sudo tee -a /etc/subuid >/dev/null
    echo "$user:$next_uid:$map_size" | sudo tee -a /etc/subgid >/dev/null
  fi
GROUP="css-podman"
BASE_UID=100000
RANGE_SIZE=65536

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root!"
  exit 1
fi

  # Set home and runtime directory for Podman
  export HOME="$podman_basedir/$user"
  export XDG_RUNTIME_DIR="$podman_basedir/$user/run"
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
