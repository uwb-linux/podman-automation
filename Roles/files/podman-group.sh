#!/bin/bash
# /opt/podman/podman-group

# Get username - either from argument or current user
if [ $# -eq 1 ]; then
    user=$1
else
    user=$(whoami)
fi

# Check if user exists
if ! id "$user" &>/dev/null; then
    echo "User $user does not exist"
    exit 1
fi

# Check if user is in css-podman group
if groups "$user" | grep -qw "css-podman"; then

    podman_basedir="/podman"

    # Create user directory if it doesn't exist
    if [ ! -d "$podman_basedir/$user" ]; then
        sudo mkdir -p "$podman_basedir/$user/run"
        sudo chown -R "$user:$user" "$podman_basedir/$user"
        sudo chmod 700 "$podman_basedir/$user"
    fi

    # Namespace mapping: Check for existing range, otherwise assign a new one
    if ! grep -q "^$user:" /etc/subuid; then
        # Find the next available UID/GID chunk; each gets 65536 ids
        last_uid=$(awk -F: '{ print $2 }' /etc/subuid | sort -n | tail -1)
        if [ -z "$last_uid" ]; then
            next_uid=100000
        else
            next_uid=$((last_uid + 65536))
        fi
        echo "$user:$next_uid:65536" | sudo tee -a /etc/subuid >/dev/null
        echo "$user:$next_uid:65536" | sudo tee -a /etc/subgid >/dev/null
    fi

    echo "Podman setup complete for user: $user"
else
    echo "User $user is not a member of css-podman group"
fi
