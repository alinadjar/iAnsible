# XWiki (Docker Compose)

Wiki stack: custom XWiki image from Nexus + PostgreSQL.

## Compose layout (`compose.yml`)

| Service | Image | Role |
|---------|--------|------|
| **web** | `nexus.sadgan.int/xwiki:18.8.0-postgres-tomcat-…` | Tomcat + XWiki 18.8.0, port **8080** |
| **db** | `postgres:latest` | Postgres for XWiki, host port **5433** → container 5432 |

- **Network:** internal `bridge` (not shared with ERP/Dify unless you attach externally).
- **Volumes:** `xwiki-data` (wiki home), `postgres-data` (DB files).
- **DB link:** `DB_HOST=xwiki-postgres-db` (Docker DNS service name).

Environment values are supplied via **`.env`** (Compose variable substitution). Ansible renders `.env` from Vault — see `ansible/roles/xwiki/templates/xwiki.env.j2`.

## `lib/` directory

Hundreds of `*.xed` files under `lib/` look like bundled extension/library metadata. They are **not** mounted in `compose.yml`. Default Ansible sync **excludes** `lib/` (`xwiki_sync_lib: false`). Set `xwiki_sync_lib: true` in `group_vars/xwiki.yml` if you add a volume mount later.

## Deploy

```bash
ansible-playbook playbooks/deploy-xwiki.yml --ask-vault-pass
```

Inventory group: **`xwiki`** (`inventory/production/hosts.yml`). Requires Nexus login if the image is private (`docker_registries` in `group_vars/all.yml`).
