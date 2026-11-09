# Offline Headroom pip wheels

Place `headroom-ai` and any dependency `.whl` files here on the **Ansible control node**.
When this directory exists, the role copies wheels to `{{ headroom_deploy_path }}/wheels/` and installs them instead of PyPI.

On a machine with internet:

```bash
mkdir -p /tmp/headroom-wheels
pip download headroom-ai -d /tmp/headroom-wheels
# copy *.whl into this folder before deploy
```

Then redeploy with `deploy-observability.yml --tags headroom`.
