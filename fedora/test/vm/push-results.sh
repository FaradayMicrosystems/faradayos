#!/bin/bash
# Pushes the VM test output folder ($GITHUB_WORKSPACE/out) to refs/vm-results/<run id>/<scenario> (no disk images)
set -e
[ -d "$GITHUB_WORKSPACE/out" ] || exit 0
T=$(mktemp -d)
rsync -a --exclude '*.ppm' --exclude '*.sock' --exclude 'disk.qcow2' --exclude 'OVMF_VARS.fd' --exclude 'boot/' --exclude 'xfer/' "$GITHUB_WORKSPACE/out/" "$T/"
cd "$T"
git init -q . && git add -A
git -c user.name=vm-bughunt -c user.email=vm-bughunt@users.noreply.github.com commit -qm "VM results run $GITHUB_RUN_ID $1"
git push -q -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/vm-results/$GITHUB_RUN_ID/$1"
echo "fetch: git fetch origin refs/vm-results/$GITHUB_RUN_ID/$1"
rm -rf "$T"
