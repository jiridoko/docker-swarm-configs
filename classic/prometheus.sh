#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Infisical value -> swarm secret named <prefix>_<sha256-prefix>. Swarm secrets are immutable,
# so after rotating a value in Infisical, re-running this script creates a new secret and
# redeploys the services using it. Prints the secret name.
infisical_swarm_secret() {
	local prefix=$1 folder=$2 key=$3 value name
	value="$(infisical-secret "$folder" "$key")"
	name="${prefix}_$(printf '%s' "$value" | sha256sum | cut -c1-12)"
	if ! docker secret inspect "$name" >/dev/null 2>&1; then
		printf '%s' "$value" | docker secret create "$name" - >/dev/null
	fi
	echo "$name"
}

ALERTMANAGER_GMAIL_SECRET="$(infisical_swarm_secret alertmanager_gmail /email GMAIL_APP_PASSWORD)"
PROMETHEUS_HA_SCRAPE_SECRET="$(infisical_swarm_secret prometheus_ha_scrape /home-assistant PROMETHEUS_HA_SCRAPE_TOKEN)"
export ALERTMANAGER_GMAIL_SECRET PROMETHEUS_HA_SCRAPE_SECRET

# Grafana <-> image renderer shared token: internal only, random, created once.
# To rotate: remove the stack's grafana + renderer services' use of it, docker secret rm, re-run.
if ! docker secret inspect grafana_renderer_token >/dev/null 2>&1; then
	openssl rand -hex 32 | tr -d '\n' | docker secret create grafana_renderer_token - >/dev/null
fi

docker stack deploy prometheus -c prometheus.yml --prune

# Remove superseded versions (in-use ones are refused by docker; a later run removes them).
for s in $(docker secret ls --format '{{.Name}}' | grep -E '^(alertmanager_gmail|prometheus_ha_scrape)_' |
	grep -vx -e "$ALERTMANAGER_GMAIL_SECRET" -e "$PROMETHEUS_HA_SCRAPE_SECRET"); do
	docker secret rm "$s" >/dev/null 2>&1 || true
done
