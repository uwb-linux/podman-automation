#!/bin/bash
# /etc/profile.d/podman-users.sh

group="css-podman"
map_size=65536
base_uid=100000
podman_basedir="/podman"

# Batch-admin mode: run as root/admin with --batch to provision for all css-podman users
if [[ $EUID -eq 0 && "$1" == "--batch" ]]; then
  users=$(getent group "$group" | awk -F: '{print $4}' | tr ',' ' ')

  # Find highest subuid used so far
  last_uid=$(awk -F: '{print $2}' /etc/subuid | sort -n | tail -1)
  if [ -z "$last_uid" ]; then
    next_uid=$base_uid
  else
    next_uid=$((last_uid + map_size))
  fi

  for user in $users; do
    # Subuid/subgid setup for each user
    if ! grep -q "^$user:" /etc/subuid; then
      echo "$user:$next_uid:$map_size" | tee -a /etc/subuid
      echo "$user:$next_uid:$map_size" | tee -a /etc/subgid
      echo "Provisioned mapping for $user"
      next_uid=$((next_uid+map_size))
    fi
    # Podman directories
    if [ ! -d "$podman_basedir/$user" ]; then
      mkdir -p "$podman_basedir/$user/run"
    fi
    chown -R "$user:$user" "$podman_basedir/$user"
    chmod 700 "$podman_basedir/$user"
    chmod 755 "$podman_basedir/$user/run"
    echo "Set directories for $user"
  done

  exit 0
fi

# Per-user login logic (profile.d)
user=$(whoami)
[[ $- != *i* ]] && return

if groups "$user" | grep -qw "$group"; then
  if [ ! -d "$podman_basedir/$user" ]; then
    mkdir -p "$podman_basedir/$user/run"
    chown "$user:$user" "$podman_basedir/$user" "$podman_basedir/$user/run"
    chmod 700 "$podman_basedir/$user"
  fi

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

  export HOME="$podman_basedir/$user"
  export XDG_RUNTIME_DIR="$podman_basedir/$user/run"
fi
