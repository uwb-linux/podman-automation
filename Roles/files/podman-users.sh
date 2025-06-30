#!/bin/bash
# Provision Podman rootless support for ALL users
# Run as root!

PODMAN_BASEDIR="/podman"
RANGE=65536
START=100000
SUBUID_FILE="/etc/subuid"
SUBGID_FILE="/etc/subgid"

for user in $(awk -F: '($3 >= 1000 && $1 != "nobody") {print $1}' /etc/passwd); do
    # 1. Podman directory
    userdir="$PODMAN_BASEDIR/$user"
    rundir="$userdir/run"
    if [ ! -d "$rundir" ]; then
        mkdir -p "$rundir"
        chown "$user":"$user" "$userdir" "$rundir"
        chmod 700 "$userdir"
        echo "Ensured podman dir for $user"
    fi

    # 2. Provision /etc/subuid
    if ! grep -q "^$user:" "$SUBUID_FILE"; then
        lastuid=$(awk -F: '{print $2 + $3}' "$SUBUID_FILE" 2>/dev/null | sort -n | tail -1)
        [ -z "$lastuid" ] && nextuid=$START || nextuid=$((lastuid))
        echo "$user:$nextuid:$RANGE" >> "$SUBUID_FILE"
        echo "Added $user:$nextuid:$RANGE to $SUBUID_FILE"
    fi

    # 3. Provision /etc/subgid
    if ! grep -q "^$user:" "$SUBGID_FILE"; then
        lastgid=$(awk -F: '{print $2 + $3}' "$SUBGID_FILE" 2>/dev/null | sort -n | tail -1)
        [ -z "$lastgid" ] && nextgid=$START || nextgid=$((lastgid))
        echo "$user:$nextgid:$RANGE" >> "$SUBGID_FILE"
        echo "Added $user:$nextgid:$RANGE to $SUBGID_FILE"
    fi

done
