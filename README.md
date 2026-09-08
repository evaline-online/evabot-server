# evabot-server
**EvaBot production application server — backend deploy & app services.**

Node: `evabot-agent-vm` (Frankfurt, c3-standard-8, 100.66.98.4)

## Contents
- `systemd/` — evabot-brain (:3000), evabot-voice (:8000), evabot-face (:8093), model-monitor, registry-sync (units + drop-ins)
- `scripts/deploy-sync.sh` — deploy pipeline to micro edge node

Related: `evabot-online` (app code) · `eva-server` (OS-level node mgmt) · `evaline-server` (edge node)
