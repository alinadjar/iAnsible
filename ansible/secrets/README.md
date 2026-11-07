# Platform secrets (Ansible Vault)

Encrypted variables live here — **not** under `inventory/`, so Ansible never treats them as inventory sources.

```bash
cp ../docs/vault.yml.example vault.yml
ansible-vault encrypt vault.yml
ansible-playbook playbooks/deploy-erp.yml --ask-vault-pass
```

If you previously used `inventory/production/vault.yml`, move and delete the old path:

```bash
mkdir -p secrets
ansible-vault decrypt inventory/production/vault.yml   # if encrypted
mv inventory/production/vault.yml secrets/vault.yml
ansible-vault encrypt secrets/vault.yml              # optional re-encrypt
rm -f inventory/production/vault.yml.example
```

Override path in `group_vars/all.yml` with `platform_secrets_file` if needed.

**After moving the vault file**, confirm keys are not still placeholders:

```bash
ansible-vault view secrets/vault.yml | grep -E 'vault_erp_postgres_password|CHANGE_ME'
ansible-vault edit secrets/vault.yml   # set real passwords, then re-run deploy
```

**Why `--ask-vault-pass` seemed to accept a wrong password:** playbooks read **`secrets/vault.yml`**, not `inventory/production/vault.yml`. If the active secrets file was missing, nothing was decrypted and `erp.env.j2` used `CHANGE_ME` defaults. Move or point `platform_secrets_file` at your real vault file; `deploy-erp` now fails fast if required `vault_*` vars are missing or still `CHANGE_ME`.
