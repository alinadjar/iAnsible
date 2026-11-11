# Sadgan platform Ansible deployment

Deploy **ERP**, **Dify**, and **Superset** from this monorepo with **one host per stack** (or collapse groups onto a single machine by putting the same `ansible_host` on multiple inventory entries).

**Detailed `site.yml` flow (Mermaid + PNG diagrams, phase-by-phase tasks, tags):** [README-site-workflow.md](README-site-workflow.md) · [diagram PNGs](docs/diagrams/)

## Layout

| Inventory group   | Playbook                 | Monorepo path   | Default deploy path   |
|-------------------|--------------------------|-----------------|-----------------------|
| `erp`             | `deploy-erp.yml`         | `erp/`          | `/opt/sadgan/erp`     |
| `dify`            | `deploy-dify.yml`        | `dify/docker/`  | `/opt/sadgan/dify/docker` |
| `superset`        | `deploy-superset.yml`    | `superset/`     | `/opt/sadgan/superset`|
| `xwiki`           | `deploy-xwiki.yml`       | `xwiki/`        | `/opt/sadgan/xwiki`   |
| `observability`   | `deploy-observability.yml` | `langfuse/`   | phase 2               |

Cross-service URLs live in `inventory/production/group_vars/platform.yml` under `platform_integration`.

## Variable precedence (golden rule)

For one variable on one host, **more specific layers win** over broader ones. From **lowest → highest** priority:

**role defaults → group_vars (parent groups, then child groups) → host_vars → play/extra vars, `set_fact`, …**

| Layer | Typical use |
|-------|----------------|
| **Role `defaults/main.yml`** | Sensible default if inventory does not set the key (e.g. `headroom_python_version: "3.12"`). |
| **`group_vars`** | Shared settings for every host in a group (`erp.yml`, `observability.yml`, `platform.yml`, …). |
| **`host_vars`** | Exceptions for a single host (different IP, one-off Python version, disk layout). |

It is normal to define the same key in **role defaults and `group_vars`** with the same value: defaults document the role; `group_vars` document your environment. When they differ, **`group_vars` overrides defaults**. **`host_vars` overrides `group_vars`** for that host only.

If two groups set the same key differently, resolution depends on group ancestry and merge order — prefer **`host_vars`** or a single owning group when you need a clear override.

Inspect the merged result:

```bash
ansible-inventory -i inventory/production --host obs-01 --yaml
ansible obs-01 -m debug -a "var=headroom_python_version"
```

Playbook-loaded secrets (`tasks/load-vault.yml`) and other play-time vars sit **above** inventory for that run. See [README-site-workflow.md](README-site-workflow.md#variables-and-secrets-loading-order).

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

Each deploy playbook loads `secrets/vault.yml` in `pre_tasks` (use `--ask-vault-pass` when the file is encrypted).

Or everything:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## Docker control node (customer on-prem)

Run Ansible from a **container** on the customer network (laptop, jump host, or CI) so you do not install `ansible-core` and collections on every machine. The image is a thin control node: SSH to targets, rsync stacks from the monorepo, vault decrypt on the controller.

**`playbooks/site.yml` order:** bootstrap → ERP → Dify → Superset → XWiki → observability (Langfuse / Headroom).

### What the image must include

| Requirement | Reason |
|-------------|--------|
| `ansible-galaxy collection install -r requirements.yml` | Roles use `community.docker`, `community.general` (UFW), `ansible.posix` (`synchronize`). |
| `rsync` | Default `stack_source: local` copies `erp/`, `langfuse/`, etc. from the control node. |
| Full **monorepo** at run time | `repo_root` is the parent of `ansible/`, not the `ansible/` folder alone. |
| SSH key + vault | Inventory uses `devops` and `secrets/vault.yml` on the controller. |

Reference Dockerfile: [`Dockerfile.ansibleFX`](Dockerfile.ansibleFX).

```bash
cd ansible
docker build -f Dockerfile.ansibleFX -t sadgan-ansible-control:latest .
```

### Customer prep (once per environment)

1. Clone the **full monorepo** on the host that runs Docker.
2. Edit `inventory/production/hosts.yml` (`ansible_host`, keys).
3. Tune `inventory/production/group_vars/*.yml` and `platform_integration` in `platform.yml`.
4. Create `secrets/vault.yml` from `docs/vault.yml.example` and `ansible-vault encrypt` it.
5. Put the matching private key on the control host; `devops` must accept it on targets.

### Deploy full site from the container

Mount the **repository root** as `/repo`, work inside `/repo/ansible`, use a vault password file (non-interactive), and **`--network host`** if the default bridge cannot reach customer LAN IPs:

```bash
export REPO=/path/to/monorepo    # parent of ansible/
export IMAGE=sadgan-ansible-control:latest

docker run --rm -it \
  --network host \
  -w /repo/ansible \
  -v "${REPO}:/repo:ro" \
  -v "${HOME}/.ssh/id_ed25519_ansible:/root/.ssh/id_ed25519_ansible:ro" \
  -v "${REPO}/ansible/secrets/vault.pass:/run/vault.pass:ro" \
  "${IMAGE}" \
  playbooks/site.yml \
  --vault-password-file /run/vault.pass
```

Align the SSH mount path with `ansible_ssh_private_key_file` in `inventory/production/hosts.yml` (default example uses `/root/.ssh/id_ed25519_ansible`).

**Ping** (override entrypoint):

```bash
docker run --rm -it --network host \
  --entrypoint ansible \
  -w /repo/ansible \
  -v "${REPO}:/repo:ro" \
  -v "${HOME}/.ssh/id_ed25519_ansible:/root/.ssh/id_ed25519_ansible:ro" \
  "${IMAGE}" \
  -i inventory/production/hosts.yml erp-01 -m ping
```

**Single stack:**

```bash
docker run --rm -it --network host -w /repo/ansible \
  -v "${REPO}:/repo:ro" \
  -v .../id_ed25519_ansible:/root/.ssh/id_ed25519_ansible:ro \
  -v "${REPO}/ansible/secrets/vault.pass:/run/vault.pass:ro" \
  "${IMAGE}" playbooks/deploy-erp.yml --vault-password-file /run/vault.pass
```

**Tags** (e.g. bootstrap only): add `--tags common` to the `ansible-playbook` argument list.

### Run-time mounts

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| Monorepo root | `/repo` | Stack trees for rsync (`repo_root` → `/repo`) |
| (workdir) | `/repo/ansible` | `ansible.cfg`, `roles/`, inventory |
| SSH private key | e.g. `/root/.ssh/id_ed25519_ansible` | Must match inventory |
| `secrets/vault.pass` | `/run/vault.pass` | Vault password file (chmod `600`) |

### Without a full monorepo mount

Set `stack_source: git`, `stack_git_url`, and `stack_git_version` in group vars so targets pull stacks from Git. You still need the `ansible/` tree (inventory, roles, secrets) in the image or mounted.

### Control-node troubleshooting

| Symptom | Fix |
|---------|-----|
| Collection not found | Rebuild image after `requirements.yml` changes. |
| `rsync: command not found` on controller | Rebuild; `Dockerfile.ansibleFX` installs `rsync`. |
| SSH `Permission denied` | Key path / user vs `hosts.yml`. |
| Empty rsync / wrong paths | `-w /repo/ansible` and mount parent repo at `/repo`. |
| Vault errors | `secrets/vault.yml` present; password file correct. |

### Docker Hub unavailable (`auth.docker.io` EOF)

If `docker build` fails with `failed to fetch oauth token` / `EOF` when pulling `python:3.12-slim`, the build host cannot reach Docker Hub — not a Dockerfile syntax error.

Check:

```bash
curl -v https://auth.docker.io/token
docker pull python:3.12-slim
```

**Workarounds:**

1. **Save/load on a connected machine:** `docker pull python:3.12-slim && docker save python:3.12-slim | gzip > python-3.12-slim.tar.gz`, copy to customer, `docker load`, then build.
2. **Private registry:** mirror `library/python:3.12-slim` to Harbor (e.g. `registry.sadgan.int/library/python:3.12-slim`) and change the `FROM` line in `Dockerfile.ansibleFX`.
3. **HTTP proxy for Docker:** systemd drop-in `HTTP_PROXY` / `HTTPS_PROXY` on `docker.service` (include `NO_PROXY` for internal registries).
4. **Registry mirror** in `/etc/docker/daemon.json` if operations provides one.

Ship a pre-built `sadgan-ansible-control:latest` tarball from CI when customer sites have no Hub access.

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
- Set `headroom_enabled: true` for **Headroom LLM Proxy** (`headroom.service`, port **8787**). Default: rsync monorepo `headroom-ai/` **including `venv/`** (`headroom_use_bundled_venv: true`) so deploy works without PyPI. If the folder is `venv-313`, set `headroom_bundled_venv_name: venv-313`. Otherwise use `headroom_python_version` + `headroom_pip_index_url` or offline wheels.

## Host TCP ports and UFW (`common`)

Each stack can set `common_check_host_ports: true` and `common_host_tcp_ports` in its `group_vars` (see `observability.yml`, `erp.yml`, …). Early in the `common` role Ansible:

1. Ensures each port is **free** or already bound by **Docker** (re-deploy safe).
2. If **UFW is active**, runs `ufw allow <port>/tcp` when the port is **vacant** (`common_ufw_auto_allow_vacant`, default true) or **Docker-bound** (`common_ufw_auto_allow_docker_bound`). Then verifies the rule exists.

Set `common_ufw_manage: true` to open every listed port regardless of listener state. Does not enable UFW.

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
