#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Alertmanager Gmail SMTP app password: Infisical /email/GMAIL_APP_PASSWORD -> swarm secret.
# Swarm secrets are immutable, so the name carries a hash of the value; after rotating the
# password in Infisical, re-running this script creates a new secret and redeploys alertmanager.
GMAIL_PASS="$(infisical-secret /email GMAIL_APP_PASSWORD)"
ALERTMANAGER_GMAIL_SECRET="alertmanager_gmail_$(printf '%s' "$GMAIL_PASS" | sha256sum | cut -c1-12)"
export ALERTMANAGER_GMAIL_SECRET
if ! docker secret inspect "$ALERTMANAGER_GMAIL_SECRET" >/dev/null 2>&1; then
	printf '%s' "$GMAIL_PASS" | docker secret create "$ALERTMANAGER_GMAIL_SECRET" - >/dev/null
fi
unset GMAIL_PASS

docker stack deploy prometheus -c prometheus.yml --prune

# Remove superseded secrets (in-use ones are refused by docker).
for s in $(docker secret ls --format '{{.Name}}' | grep '^alertmanager_gmail_' | grep -vx "$ALERTMANAGER_GMAIL_SECRET"); do
	docker secret rm "$s" >/dev/null 2>&1 || true
done
