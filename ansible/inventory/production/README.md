# Production inventory

| File | Purpose |
|------|---------|
| `hosts.yml` | Inventory hosts and groups |
| `group_vars/` | Vars per group (`all.yml`, `erp.yml`, …) |
| `hosts.ini.example` | Reference only — not loaded |

**Secrets:** `ansible/secrets/vault.yml` (see [secrets/README.md](../../secrets/README.md)).

**Keep this directory free of** `vault.yml`, `vault.yml.example`, or other extra `*.yml` files at this level. If `ansible.cfg` sets `inventory = inventory/production` (the folder), Ansible will try to parse every file as inventory and fail on vault or YAML templates.

**Do not use** `group_vars/all/vault.yml` — Ansible auto-loads it and requires a vault password on every command.
