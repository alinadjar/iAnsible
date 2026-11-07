# Sadgan platform Ansible deployment

Deploy **ERP**, **Dify**, and **Superset** from this monorepo with **one host per stack** (or collapse groups onto a single machine by putting the same `ansible_host` on multiple inventory entries).

**Detailed `site.yml` flow (Mermaid + PNG diagrams, phase-by-phase tasks, tags):** [README-site-workflow.md](README-site-workflow.md) · [diagram PNGs](docs/diagrams/)

## Layout

| Inventory group   | Playbook                 | Monorepo path   | Default deploy path   |
|-------------------|--------------------------|-----------------|-----------------------|
| `erp`             | `deploy-erp.yml`         | `erp/`          | `/opt/sadgan/erp`     |
| `dify`            | `deploy-dify.yml`        | `dify/docker/`  | `/opt/sadgan/dify`    |
| `superset`        | `deploy-superset.yml`    | `superset/`     | `/opt/sadgan/superset`|
| `xwiki`           | `deploy-xwiki.yml`       | `xwiki/`        | `/opt/sadgan/xwiki`   |
| `observability`   | `deploy-observability.yml` | `langfuse/`   | phase 2               |

Cross-service URLs live in `inventory/production/group_vars/platform.yml` under `platform_integration`.

## Quick start

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml

mkdir -p secrets
cp docs/vault.yml.example secrets/vault.yml
ansible-vault encrypt secrets/vault.yml

# Edit hosts, secrets, and URLs
vim inventory/production/hosts.yml
vim inventory/production/group_vars/all.yml

ansible-playbook playbooks/deploy-erp.yml --ask-vault-pass
ansible-playbook playbooks/deploy-dify.yml --ask-vault-pass
ansible-playbook playbooks/deploy-superset.yml --ask-vault-pass
ansible-playbook playbooks/deploy-xwiki.yml --ask-vault-pass
```

Or everything:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Separate server for Dify

1. Put Dify in the `dify` group and ERP in `erp` (different `ansible_host` values).
2. Set `platform_integration.dify_public_url` to the URL ERP users and workflows use.
3. Open **HTTPS** from ERP (and operators) to Dify; Dify’s `docker-compose.sadgan.yaml` overlay is applied and `SSRF_PROXY_ALLOW_PRIVATE_DOMAINS` is set from ERP host IPs in `group_vars/dify.yml`.
4. Configure ERP (or Dify tools) with the Dify **Service API** base URL — not container DNS names across hosts.

## Superset ↔ ERP data

ERP exposes Postgres read traffic on HAProxy port **5401** (see `erp/compose.yaml`). Superset runs on its own host and connects using `superset_erp_sqlalchemy_uri` in `group_vars/superset.yml` (BI user from `erp/init` SQL scripts).

Allow **TCP 5401** from the Superset host to the ERP host in the firewall.

## Source of stack files

- **`stack_source: local`** (default): rsync from this repo on the machine where you run Ansible.
- **`stack_source: git`**: clone `stack_git_url` on the target; set `stack_git_version`.

Do **not** commit `erp/.env`; secrets are rendered from Ansible Vault into `.env` on the server.

## Phase 2: Langfuse & Headroom

- Set `langfuse_enabled: true` in `group_vars/observability.yml` and fill vault secrets.
- Set `headroom_enabled: true` to install **Headroom LLM Proxy** as `headroom.service` under `/opt/headroom-ai` (Python 3.13 venv `venv-313`, port **8787** by default). Override `headroom_pip_packages` / `headroom_pip_extra_args` if you use a private PyPI index or version pin.

## Docker daemon (private registry)

`common` **merges** `registry.sadgan.int` into `insecure-registries` in an existing `/etc/docker/daemon.json` (other keys unchanged). If the file is missing, it creates one with log rotation defaults. Restarts Docker when the file changes, then runs `docker info`. Add more hosts via `docker_daemon_insecure_registries_add` in `group_vars/all.yml`.

## ERP prerequisites on the server

`erp/compose.yaml` expects external Docker networks `net_fx_alpha`, `redis_insight`, and volume `pg-csv-exports-demo`. The `erp` role creates these before `docker compose up`.

## Test connectivity (no vault password)

`ansible.cfg` uses **`inventory/production/hosts.yml` only** (not the whole `production/` directory).

```bash
cd ansible
ansible all -m ping
ansible-inventory --host erp-01 -y | grep platform_integration
```

**If you see vault/inventory warnings**, the control node is almost always using **directory** inventory (`inventory/production/`) and/or vault files still live under that folder. Fix:

```bash
cd /path/to/ansible
grep '^inventory' ansible.cfg
ansible-config dump | grep -i INVENTORY   # must list .../hosts.yml only
echo "${ANSIBLE_INVENTORY:-<unset>}"    # should be unset
rm -f inventory/production/vault.yml inventory/production/vault.yml.example
rm -f inventory/production/group_vars/all/vault.yml
# move secrets out of inventory (playbooks load secrets/vault.yml)
mkdir -p secrets && mv inventory/production/vault.yml secrets/vault.yml 2>/dev/null || true
```

See [secrets/README.md](secrets/README.md) and [inventory/production/README.md](inventory/production/README.md).

Use `--ask-vault-pass` for playbooks when `secrets/vault.yml` exists.
