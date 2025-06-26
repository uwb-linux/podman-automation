#!/bin/bash
# /etc/profile.d/podman-users.sh

user=$(whoami)

[[ $- != *i* ]] && return

if groups "$user" | grep -qw "css-podman"; then
    podman_basedir="/podman"
    if [ ! -d "$podman_basedir/$user" ]; then
        mkdir -p "$podman_basedir/$user/run"
        chmod 700 "$podman_basedir/$user"
    fi
    if ! grep -q "^$user:" /etc/subuid; then
        last_uid=$(awk -F: '{ print $2 }' /etc/subuid | sort -n | tail -1)
        if [ -z "$last_uid" ]; then
            next_uid=100000
        else
            next_uid=$((last_uid + 65536))
        fi
        echo "$user:$next_uid:65536" | sudo tee -a /etc/subuid >/dev/null
        echo "$user:$next_uid:65536" | sudo tee -a /etc/subgid >/dev/null
    fi
    export HOME="$podman_basedir/$user"
    export XDG_RUNTIME_DIR="$podman_basedir/$user/run"
fi