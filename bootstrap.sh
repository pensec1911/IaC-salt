#!/usr/bin/env bash
# One-time bootstrap: gets this repo's state tree onto a fresh salt-master
# so it can start pulling formulas/salt/pillar directly from git itself
# (gitfs + git_pillar). This automates the "One-time bootstrap" steps from
# README.md — see that section if you want to understand or do it by hand.
#
# Everything after this is state-managed (pushing to the repo is enough,
# salt-master picks up changes on its own). This script only ever needs to
# run once per master, and is safe to re-run if it fails partway through.
#
# Usage: ./bootstrap.sh <user>@<salt-master-host>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <user>@<salt-master-host>" >&2
  exit 1
fi

TARGET="$1"
REMOTE_TMP=/tmp/iac-salt-bootstrap
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TMP="$(mktemp -d)"
trap 'rm -rf "$LOCAL_TMP"' EXIT

echo "==> Staging formulas/ + salt/ + pillar/ locally"
mkdir -p "$LOCAL_TMP/salt"
cp -r "$REPO_ROOT"/formulas/. "$LOCAL_TMP/salt/"
cp -r "$REPO_ROOT"/salt/. "$LOCAL_TMP/salt/"
cp -r "$REPO_ROOT/pillar" "$LOCAL_TMP/pillar"

echo "==> Copying to $TARGET:$REMOTE_TMP"
ssh "$TARGET" "sudo rm -rf $REMOTE_TMP && sudo mkdir -p $REMOTE_TMP && sudo chown \$(id -u):\$(id -g) $REMOTE_TMP"
scp -rq "$LOCAL_TMP/salt" "$LOCAL_TMP/pillar" "$TARGET:$REMOTE_TMP/"

echo "==> Applying the salt-master formula locally on $TARGET"
ssh "$TARGET" "sudo salt-call --local \
  --file-root=$REMOTE_TMP/salt \
  --pillar-root=$REMOTE_TMP/pillar \
  state.apply salt-master"

DEPLOY_KEY="$(ssh "$TARGET" "sudo cat /etc/salt/pki/master/gitfs/id_ed25519.pub")"
echo
echo "==> Deploy key generated on $TARGET:"
echo "$DEPLOY_KEY"
echo

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  read -rp "Add this as a READ-ONLY deploy key on the IaC-salt repo via gh now? [y/N] " ADD_KEY
  if [[ "$ADD_KEY" =~ ^[Yy]$ ]]; then
    echo "$DEPLOY_KEY" | gh repo deploy-key add - --title "salt-master-gitfs-$(date +%Y%m%d)" --repo pensec1911/IaC-salt
  else
    echo "Skipped — add it manually: https://github.com/pensec1911/IaC-salt/settings/keys"
  fi
else
  echo "(gh not installed/authenticated — add the key manually as READ-ONLY:"
  echo " https://github.com/pensec1911/IaC-salt/settings/keys)"
fi

read -rp "Once the deploy key is added on GitHub, press enter to restart salt-master and fetch..." _

ssh "$TARGET" "sudo systemctl restart salt-master && sudo salt-run fileserver.update"
ssh "$TARGET" "sudo rm -rf $REMOTE_TMP"

echo "==> Done. $TARGET now pulls formulas/salt/pillar directly from git (gitfs_update_interval, default 60s)."
echo "==> Remaining manual step (separate from this): the OpenBao AppRole secret_id file for"
echo "    formulas/salt-master/vault.sls — see formulas/salt-master/README.md \"OpenBao AppRole\"."
