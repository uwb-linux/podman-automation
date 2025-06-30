#!/bin/bash

user=$(whoami)

# Only run in interactive shells
[[ $- != *i* ]] && return

# Only proceed if user is in the css-podman group
if groups "$user" | grep -qw "css-podman"; then
    podman_basedir="/podman"
    if [ ! -d "$podman_basedir/$user" ]; then
        mkdir -p "$podman_basedir/$user/run"
        chmod 700 "$podman_basedir/$user"
    fi

    missing=0
    if ! grep -q "^$user:" /etc/subuid; then
        missing=1
        echo "    echo \"$user:$(awk -F: '{ print $2 }' /etc/subuid | sort -n | tail -1)+65536:65536\" >> /etc/subuid"
    fi
    if ! grep -q "^$user:" /etc/subgid; then
        missing=1
       
        echo "    echo \"$user:$(awk -F: '{ print $2 }' /etc/subgid | sort -n | tail -1)+65536:65536\" >> /etc/subgid"
    fi

    if [ "$missing" -eq 0 ]; then
        export HOME="$podman_basedir/$user"
        export XDG_RUNTIME_DIR="$podman_basedir/$user/run"
    fi
fi
