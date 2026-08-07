#!/bin/bash
# Phase E (host-side): the COW-isolation check on the ORIGINAL pod. It must NOT see
# the clone-only files, but must still have its own before-app.txt.
set +e
exec 2>&1
kubectl exec kata-pyruntime -- python3 -c "
import urllib.request, json
cmd = 'sh -c \"echo APP_CLONE_ONLY:; ls /app/clone-only.txt 2>&1; echo TMP_CLONE_ONLY:; ls /tmp/clone-only.txt 2>&1; echo ORIG_BEFORE_STILL_THERE:; cat /app/before-app.txt 2>&1\"'
data = json.dumps({'command': cmd}).encode()
req = urllib.request.Request('http://127.0.0.1:8888/execute', data=data, headers={'Content-Type':'application/json'}, method='POST')
print(urllib.request.urlopen(req, timeout=15).read().decode())
"
echo "(PASS = original sees No such file for BOTH clone-only.txt, but DOES have before-app.txt)"
