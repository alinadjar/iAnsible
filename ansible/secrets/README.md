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
