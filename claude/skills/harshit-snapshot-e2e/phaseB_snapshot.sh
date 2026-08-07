#!/bin/bash
# Phase B (node): snapshot via CLI - default, --name, coexistence.
set +e
exec 2>&1
SBID=$(crictl pods --name kata-pyruntime -q | head -1)
echo "SBID=$SBID"
echo ""
echo "######## B1. default sbid-named snapshot ########"
/usr/local/bin/kata-runtime snapshot create --path /run/vc/vm/snapshots/"$SBID" --sandbox-id "$SBID"
echo "snapshot-rc=$?"
ls -la /run/vc/vm/snapshots/"$SBID"/
echo "--- manifest ---"; cat /run/vc/vm/snapshots/"$SBID"/kata-snapshot.json
echo ""
echo "######## B2. second snapshot at a different path ########"
/usr/local/bin/kata-runtime snapshot create --path /run/vc/vm/snapshots/pyrt-named --sandbox-id "$SBID"
echo "rc=$?"; ls -la /run/vc/vm/snapshots/pyrt-named/ | head -3
echo ""
echo "######## B3. both coexist ########"
ls -d /run/vc/vm/snapshots/*/ 2>/dev/null
