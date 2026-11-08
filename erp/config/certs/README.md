# TLS files for nginx (generated on the server)

Ansible creates self-signed `server.crt` and `server.key` here during `deploy-erp` (when not already present).

Mount in `compose.yaml` when enabling HTTPS, for example:

```yaml
volumes:
  - ./config/certs:/etc/nginx/certs:ro
```

Do not commit private keys. This directory is excluded from rsync replace on deploy.
