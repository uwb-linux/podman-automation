---
- hosts: all
  become: true
  tasks:
    - name: Remove podman-users.sh
      file:
        path: /etc/profile.d/podman-users.sh
        state: absent

    - name: Remove podman-users.sh.BAK
      file:
        path: /etc/profile.d/podman-users.sh.BAK
        state: absent
