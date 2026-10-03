#!/usr/bin/env bash
set -euo pipefail
image=${1:?Pass the image to test}
name=sparkdash-ci
# This token only protects the disposable CI container.
token=sparkdash-ci-smoke-token
cleanup() {
  docker logs "$name" || true
  docker rm -fv "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT
echo "Checking image architecture"
[[ $(docker image inspect "$image" --format '{{.Architecture}}') == amd64 ]]
docker run -d --name "$name" -p 127.0.0.1:5555:5555 \
  -e BIND_HOST=0.0.0.0 -e SPARKDASH_ALLOW_OPEN_REMOTE=0 \
  -e SPARKDASH_TOKEN="$token" "$image"
ready=false
for attempt in {1..60}; do
  if curl --silent --fail -H "Authorization: Bearer $token" \
    http://127.0.0.1:5555/api/health > /tmp/sparkdash-health.json; then
    ready=true
    break
  fi
  sleep 1
done
[[ $ready == true ]]
echo "Checking health, frontend, API authentication, and WebSocket"
python3 -c 'import json; h=json.load(open("/tmp/sparkdash-health.json")); assert h["ok"] and h["authMode"] == "bearer", h'
curl --silent --fail -H "Authorization: Bearer $token" http://127.0.0.1:5555/ > /tmp/sparkdash-index.html
grep -qi '<!doctype html>' /tmp/sparkdash-index.html
[[ $(curl --silent -o /dev/null -w '%{http_code}' http://127.0.0.1:5555/api/sparks) == 401 ]]
curl --silent --fail -H "Authorization: Bearer $token" http://127.0.0.1:5555/api/sparks \
  | python3 -c 'import json,sys; assert isinstance(json.load(sys.stdin)["sparks"], list)'
docker exec -e TEST_TOKEN="$token" "$name" node --input-type=module -e '
  import WebSocket from "ws";
  const timer = setTimeout(() => { console.error("WebSocket timed out"); process.exit(1); }, 10000);
  const ws = new WebSocket("ws://127.0.0.1:5555/ws", {headers: {Authorization: `Bearer ${process.env.TEST_TOKEN}`}});
  ws.on("message", data => { JSON.parse(data.toString()); clearTimeout(timer); ws.close(); });
  ws.on("error", error => { console.error(error); process.exit(1); });
'
