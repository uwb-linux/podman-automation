#!/bin/bash
# Podman Rootless Automation for All Users (run as root)

PODMAN_BASEDIR="/podman"
RANGE=65536
START=100000
SUBUID_FILE="/etc/subuid"
SUBGID_FILE="/etc/subgid"

# Figure out next available subuid/subgid range (safely avoids overlaps)
get_next_range() {
    local file=$1
    local lastid
    lastid=$(awk -F: '{print $2+$3}' "$file" 2>/dev/null | sort -n | tail -1)
    if [[ -z "$lastid" ]]; then
        echo $START
    else
        echo $lastid
    fi
}

for user in $(awk -F: '($3 >= 1000) && ($1 != "nobody") {print $1}' /etc/passwd); do
    # Podman dirs (idempotent)
    userdir="$PODMAN_BASEDIR/$user"
    rundir="$userdir/run"
    if [ ! -d "$rundir" ]; then
        mkdir -p "$rundir"
        chown "$user:$user" "$userdir" "$rundir"
        chmod 700 "$userdir"
        chmod 700 "$rundir"
        echo "Ensured podman dir for $user"
    fi

    # Subuid
    if ! grep -q "^$user:" "$SUBUID_FILE"; then
        nextuid=$(get_next_range "$SUBUID_FILE")
        echo "$user:$nextuid:$RANGE" >> "$SUBUID_FILE"
        echo "Added $user:$nextuid:$RANGE to $SUBUID_FILE"
    fi

    # Subgid
    if ! grep -q "^$user:" "$SUBGID_FILE"; then
        nextgid=$(get_next_range "$SUBGID_FILE")
        echo "$user:$nextgid:$RANGE" >> "$SUBGID_FILE"
        echo "Added $user:$nextgid:$RANGE to $SUBGID_FILE"
    fi
done
