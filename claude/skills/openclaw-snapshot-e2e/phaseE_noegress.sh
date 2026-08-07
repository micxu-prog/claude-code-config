#!/bin/bash
# Phase E (node): TEACHING BEAT — the clone has no egress (Mode A limitation).
# Proven via the clone's route table: NO default route => off-subnet/outbound is
# unreachable. openclaw serves its surviving UI/state INBOUND, but a real LLM agent
# turn needs outbound HTTPS+DNS, which the clone cannot do.
set +e
exec 2>&1
AGENT=/kata-containers/src/tools/agent-ctl/target/release/kata-agent-ctl
VSOCK=/tmp/openclaw-clone/clone-vm.vsock

echo "######## clone route table (the egress wall) ########"
timeout 15 $AGENT connect --server-address "unix://$VSOCK" --hybrid-vsock true -c ListRoutes 2>&1 \
  | grep -oE 'dest: \\"[^\\]*\\"' | head
echo ""
echo "Expect only on-link routes (10.244.0.0/16, 192.168.<240+N>.0/24, fe80::/64) and"
echo "NO 0.0.0.0 default route. => the clone cannot reach off-subnet/outbound."
echo "Consequence: openclaw's Control UI + surviving state work INBOUND, but an LLM"
echo "agent turn on the clone fails at the outbound provider call. This is the documented"
echo "Mode A limitation (see nodepool0-restore-networking-reference.md), not a restore bug."
