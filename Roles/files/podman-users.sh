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

  # Set home and runtime directory for Podman
  export HOME="$podman_basedir/$user"
  export XDG_RUNTIME_DIR="$podman_basedir/$user/run"
fi
