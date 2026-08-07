#!/bin/bash
# Phase B (node): snapshot the running openclaw via the shipped CLI.
set +e
exec 2>&1
SBID=$(crictl pods --name kata-openclaw -q | head -1)
echo "SBID=$SBID"
echo ""
echo "######## snapshot via kata-runtime snapshot --sandbox-id ########"
/usr/local/bin/kata-runtime snapshot --sandbox-id "$SBID"
echo "snapshot-rc=$?"
echo "--- output (5 files; memory-ranges ~ guest RAM size) ---"
ls -la /run/vc/vm/snapshots/"$SBID"/
echo "--- manifest ---"; cat /run/vc/vm/snapshots/"$SBID"/kata-snapshot.json
