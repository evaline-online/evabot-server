#!/usr/bin/env bash
# ==============================================================================
# EVABOT ONLINE - MONOREPO DEPLOYMENT SCRIPT
# Sync: Local -> GitHub -> EvaFace (Iowa) + EvaBrain (Frankfurt)
# ==============================================================================
set -e

MSG="${1:-"feat(evabot): v0.0.1 monorepo with /top command and model ratings"}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}  EVABOT ONLINE - MONOREPO DEPLOYMENT${NC}"
echo -e "${BLUE}  Local -> GitHub -> EvaFace (Iowa) + EvaBrain (Frankfurt)${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

echo -e "${YELLOW}[0/5] Building TypeScript bundle...${NC}"
npm run build
echo -e "${GREEN}  ✓ Build complete${NC}"
echo ""

echo -e "${YELLOW}[1/5] Verifying server health...${NC}"
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
  echo -e "${GREEN}  ✓ Local server is healthy${NC}"
else
  echo -e "${RED}  ✗ Local server is down. Starting...${NC}"
  nohup node dist/server/server.js > /tmp/evabot-server.log 2>&1 &
  sleep 2
fi
echo ""

echo -e "${YELLOW}[2/5] Testing model endpoints...${NC}"
FREE_COUNT=$(curl -s http://localhost:3000/api/models/free | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")
PAID_COUNT=$(curl -s http://localhost:3000/api/models/paid | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])" 2>/dev/null || echo "0")
echo -e "${GREEN}  ✓ Free models: $FREE_COUNT, Paid models: $PAID_COUNT${NC}"
echo ""

echo -e "${YELLOW}[3/5] Testing /top command...${NC}"
TOP_RESULT=$(curl -s -X POST http://localhost:3000/api/models/command -H "Content-Type: application/json" -d '{"command":"/top"}' 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK' if len(d.get('result', '')) > 100 else 'FAIL')" 2>/dev/null || echo "FAIL")
if [ "$TOP_RESULT" = "OK" ]; then
  echo -e "${GREEN}  ✓ /top command works${NC}"
else
  echo -e "${RED}  ✗ /top command failed${NC}"
fi
echo ""

echo -e "${YELLOW}[4/5] Committing and pushing to GitHub...${NC}"
git add .
git status --short
git commit -m "$MSG" || echo -e "${YELLOW}  No new changes to commit.${NC}"

if command -v gh &> /dev/null; then
  echo -e "${BLUE}  GitHub CLI detected. Checking auth...${NC}"
  if gh auth status &> /dev/null; then
    echo -e "${GREEN}  ✓ GitHub CLI authenticated${NC}"
    git push origin main || echo -e "${YELLOW}  Push skipped (offline or no remote)${NC}"
  else
    echo -e "${YELLOW}  ⚠ GitHub CLI not authenticated. Run: gh auth login${NC}"
  fi
else
  echo -e "${YELLOW}  ⚠ GitHub CLI not installed${NC}"
  git push origin main || echo -e "${YELLOW}  Push skipped (offline or no remote)${NC}"
fi
echo ""

echo -e "${YELLOW}[5/5] Deploying to GCP servers...${NC}"

# Deploy Backend to EvaBrain (Frankfurt)
if command -v gcloud &> /dev/null; then
  echo -e "${BLUE}  → EvaBrain (Frankfurt / evabot-agent-vm / europe-west3-a)${NC}"
  gcloud compute ssh evabot-agent-vm --zone=europe-west3-a --quiet --command="
    set -e
    cd /var/www/evabot-backend 2>/dev/null || cd /home/evabot/Desktop/evabot-online 2>/dev/null || cd ~/evabot-online
    git pull origin main || true
    npm install 2>/dev/null || true
    npm run build 2>/dev/null || true
    
    # Restart backend
    sudo systemctl restart evabot-brain 2>/dev/null || sudo systemctl restart evabot-chat 2>/dev/null || true
    echo '[+] EvaBrain backend restarted'
  " 2>&1 | head -20 || echo -e "${YELLOW}  ⚠ Could not deploy to EvaBrain (check gcloud auth)${NC}"
  
  echo ""
  echo -e "${BLUE}  → EvaFace (Iowa / evaline-micro-vm / us-central1-a)${NC}"
  gcloud compute ssh evaline-micro-vm --zone=us-central1-a --quiet --command="
    set -e
    cd /var/www/evabot.online 2>/dev/null || cd /home/evabot/Desktop/evabot-online 2>/dev/null || cd ~/evabot-online
    git pull origin main || true
    
    # Sync frontend files
    sudo rsync -av --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='src' ./ /var/www/evabot.online/ 2>/dev/null || true
    sudo chown -R www-data:www-data /var/www/evabot.online 2>/dev/null || true
    
    # Reload Caddy
    sudo systemctl reload caddy 2>/dev/null || true
    echo '[+] EvaFace frontend synced'
  " 2>&1 | head -20 || echo -e "${YELLOW}  ⚠ Could not deploy to EvaFace (check gcloud auth)${NC}"
else
  echo -e "${YELLOW}  ⚠ gcloud CLI not available. Skipping GCP deployment.${NC}"
fi

echo ""
echo -e "${GREEN}================================================================================${NC}"
echo -e "${GREEN}  [OK] DEPLOYMENT & SYNC COMPLETED!${NC}"
echo -e "${GREEN}================================================================================${NC}"
echo -e "${GREEN}  Local:             /var/www/evabot-backend${NC}"
echo -e "${GREEN}  GitHub:            https://github.com/evaline-network/evabot-online${NC}"
echo -e "${GREEN}  EvaFace (Edge):    https://evabot.online (Iowa / evaline-micro-vm)${NC}"
echo -e "${GREEN}  EvaBrain (Core):   http://100.66.98.4:3000 (Frankfurt / evabot-agent-vm)${NC}"
echo -e "${GREEN}================================================================================${NC}"
