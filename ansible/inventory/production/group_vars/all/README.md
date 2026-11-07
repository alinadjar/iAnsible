# Do not put vault.yml here

Ansible auto-loads every `*.yml` in `group_vars/all/` for inventory group `all`. An encrypted `vault.yml` breaks `ping` and leaves other vars unloaded.

Secrets: `ansible/secrets/vault.yml` (playbooks only). Template: `docs/vault.yml.example`.
