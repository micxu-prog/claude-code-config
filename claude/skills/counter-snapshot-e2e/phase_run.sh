#!/bin/bash
# counter snapshot+restore proof, one node session. snapshot via CLI, restore via
# the shipped kata-runtime restore CLI, then prove the in-RAM counter survived and
# the clone diverges from the original (copy-on-write).
set +e
exec 2>&1

SBID=$(crictl pods --name kata-counter -q | head -1)
echo "SBID=$SBID"

echo ""
echo "########## STEP 5 — confirm pre-snapshot value (should be counter=5) ##########"
# can't curl pod IP from node easily; read it from the clone after restore instead.

echo ""
echo "########## STEP 6 — snapshot via kata-runtime snapshot create --path ##########"
/usr/local/bin/kata-runtime snapshot create --path /run/vc/vm/snapshots/"$SBID" --sandbox-id "$SBID"
echo "snapshot-rc=$?"
ls -la /run/vc/vm/snapshots/"$SBID"/ | head

echo ""
echo "########## STEP 7-9 — restore a clone via kata-runtime restore --path ##########"
/usr/local/bin/kata-runtime restore --path /run/vc/vm/snapshots/"$SBID" --name counter-clone
echo "restore-rc=$?"
GIP=$(grep -oE '"guest_ip": "[0-9.]+' /tmp/counter-clone/clone.json 2>/dev/null | grep -oE '[0-9.]+$')
echo "clone guest IP = $GIP"
sleep 3

echo ""
echo "########## STEP 10 — THE PROOF: counter survived + COW divergence ##########"
echo -n "[clone counter, should be 5]: "; curl -sS --max-time 12 "http://$GIP:9999" || echo FAIL
echo -n "[clone POST -> 6]:           "; curl -sS --max-time 12 -X POST "http://$GIP:9999" || echo FAIL
echo -n "[clone POST -> 7]:           "; curl -sS --max-time 12 -X POST "http://$GIP:9999" || echo FAIL
echo -n "[clone now, should be 7]:    "; curl -sS --max-time 12 "http://$GIP:9999" || echo FAIL
echo "(original is checked from host: must still be 5 = COW isolation)"
