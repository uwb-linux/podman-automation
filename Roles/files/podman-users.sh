#!/bin/bash
# /etc/profile.d/podman-users.sh - setup per-user podman envs and subuid/subgid mapping

group="css-podman"
map_size=65536
base_uid=100000
podman_basedir="/podman"

batch_provision=0
if [[ $EUID -eq 0 && "$1" == "--batch" ]]; then
  batch_provision=1
fi

if (( batch_provision )); then
  echo "BATCH PROVISION MODE: for all users in $group"

  users=$(getent group "$group" | awk -F: '{print $4}' | tr ',' ' ')
  last_uid=$(awk -F: '{print $2}' /etc/subuid | sort -n | tail -1)
  if [ -z "$last_uid" ]; then
    next_uid=$base_uid
  else
    next_uid=$((last_uid+map_size))
  fi

  for user in $users; do
    # Add subuid/subgid if missing
    if ! grep -q "^$user:" /etc/subuid; then
      echo "$user:$next_uid:$map_size" | tee -a /etc/subuid
      echo "$user:$next_uid:$map_size" | tee -a /etc/subgid
      echo "Added mapping for $user"
      next_uid=$((next_uid+map_size))
    else
      echo "Mapping already exists for $user"
    fi
    # Dir setup
    if [ ! -d "$podman_basedir/$user" ]; then
      mkdir -p "$podman_basedir/$user/run"
    fi
    chown -R "$user:$user" "$podman_basedir/$user"
    chmod 700 "$podman_basedir/$user"
    chmod 755 "$podman_basedir/$user/run"
    echo "Provisioned directories for $user"
  done
  exit 0
fi

#########################################################
# Per-user (profile.d, login) logic (the regular user flow)

user=$(whoami)
[[ $- != *i* ]] && return

if groups "$user" | grep -qw "$group"; then
  # Ensure directories and permissions
  if [ ! -d "$podman_basedir/$user" ]; then
    mkdir -p "$podman_basedir/$user/run"
    chown "$user:$user" "$podman_basedir/$user" "$podman_basedir/$user/run"
    chmod 700 "$podman_basedir/$user"
  fi

  # Subuid/subgid mapping attempt (fallback for new users with sudo)
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
