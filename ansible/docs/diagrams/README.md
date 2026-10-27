# Workflow diagrams (Mermaid + PNG)

Sources live as `*.mmd` in this folder. Matching `*.png` files are checked in for viewers that do not render Mermaid (PDF, some IDEs, wikis).

## Regenerate PNGs

Requires [Node.js](https://nodejs.org/) (uses `@mermaid-js/mermaid-cli` via `npx`):

```powershell
cd ansible/docs/diagrams
./render.ps1
```

On Linux/macOS:

```bash
cd ansible/docs/diagrams
for f in *.mmd; do
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "${f%.mmd}.png" -b transparent -s 2
done
```

## Index

| PNG | Description |
|-----|-------------|
| [01-site-yml-orchestration.png](01-site-yml-orchestration.png) | `site.yml` import order and host groups |
| [02-inventory-groups.png](02-inventory-groups.png) | Inventory parent/child groups |
| [03-phase-bootstrap.png](03-phase-bootstrap.png) | Bootstrap / `common` role |
| [04-phase-erp.png](04-phase-erp.png) | ERP deploy playbook flow |
| [05-erp-stack-sync.png](05-erp-stack-sync.png) | ERP file sync (`stack_source`) |
| [06-phase-dify.png](06-phase-dify.png) | Dify deploy playbook flow |
| [07-phase-superset.png](07-phase-superset.png) | Superset deploy playbook flow |
| [08-phase-observability.png](08-phase-observability.png) | Observability playbook flow |
| [09-stack-deploy-sequence.png](09-stack-deploy-sequence.png) | `stack_deploy` two-phase sequence |
| [10-variables-merge.png](10-variables-merge.png) | Variable merge → templates → `.env` |
| [11-platform-connectivity.png](11-platform-connectivity.png) | Post-deploy service connectivity |
