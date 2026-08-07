#!/bin/bash
# Phase A (host-side): drive Harshit's /execute endpoint via kubectl exec.
# Captures the in-guest overlay fs model and writes the BEFORE-snapshot proof files
# to BOTH /app (image layer -> overlay upper) and /tmp.
# NOTE: /execute runs commands argv-style (shlex, NO shell), so every shell feature
# (redirects, &&, pipes) MUST be wrapped in:  sh -c "<cmd>"
set +e
exec 2>&1

run() {  # run a shell command inside the guest via /execute
  kubectl exec kata-pyruntime -- python3 -c "
import urllib.request, json, sys
cmd = sys.argv[1]
data = json.dumps({'command': cmd}).encode()
req = urllib.request.Request('http://127.0.0.1:8888/execute', data=data, headers={'Content-Type':'application/json'}, method='POST')
try:
    o = json.loads(urllib.request.urlopen(req, timeout=20).read().decode())
    sys.stdout.write(o.get('stdout',''))
    if o.get('stderr'): sys.stdout.write('STDERR: '+o['stderr'])
    sys.stdout.write('[exit=%s]\n' % o.get('exit_code'))
except Exception as e:
    print('EXEC-ERR', e)
" "sh -c \"$1\""
}

echo "=== /execute sanity ==="; run "echo hello-from-execute; id -u"
echo ""
echo "=== in-guest rootfs is OVERLAY (erofs RO lower + RAM-backed upper)? ==="
run "mount | grep ' / ' | head -2"
echo ""
echo "=== /, /app, /tmp all on the same overlay? ==="
run "df -hT / /app /tmp"
echo ""
echo "=== any writable NON-RAM mount (would NOT survive a RAM snapshot)? expect none ==="
run "mount | grep -v virtual-volumes | grep -v overlay | grep -v tmpfs | grep -v proc | grep -v sysfs | grep -v cgroup | grep -v devpts | grep -v mqueue | grep -v 'on /dev ' | head"
echo ""
echo "######## WRITE BEFORE-SNAPSHOT PROOF FILES ########"
run "echo hello-from-original-APP > /app/before-app.txt; cat /app/before-app.txt"
run "echo hello-from-original-TMP > /tmp/before-tmp.txt; cat /tmp/before-tmp.txt"
