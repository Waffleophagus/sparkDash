# sparkDash AMD64 containers

This fork packages [MiaAI-Lab/sparkDash](https://github.com/MiaAI-Lab/sparkDash)
for x86-64 Linux and Unraid. Application code and the Dockerfile are unmodified.

- `main`: upstream source, synced by the build workflow.
- `container` (default): packaging workflow, smoke test, and Unraid configuration.
- Image: `ghcr.io/waffleophagus/sparkdash:latest` (`linux/amd64`).
- Rollback tags: `sha-<full upstream commit SHA>`.

## Updates and builds

GitHub Actions checks upstream daily at 06:23 UTC. A changed source revision or
packaging workflow triggers a build; unchanged scheduled runs skip the build.
You can also run **Sync upstream and publish AMD64 image** manually, selecting
**force** to rebuild an unchanged revision. Sync and build happen in the same run,
so syncing with `GITHUB_TOKEN` does not need to trigger another workflow.

The workflow builds upstream's Dockerfile on a GitHub-hosted AMD64 runner,
checks architecture, frontend, authenticated health/API, authentication rejection,
and WebSocket delivery, then publishes the tested image to GHCR. Failed builds
leave `latest` and the successful revision marker unchanged. `.upstream-sha`
records the last published source revision; `main` can be ahead if a build fails.

No personal access token is required by the build. GitHub's built-in token has
repository contents and package write permission. Sync conflicts fail without
force-overwriting branches. Keep local source changes off `main`.

GitHub may disable scheduled workflows after 60 days without repository activity.
If upstream is quiet that long, re-enable the workflow from Actions. Successful
updates commit the revision marker, but unchanged runs do not create dummy commits.

## First-time GHCR setup

GitHub initially creates container packages as private, even for public repos.
After the first publish, open the package's settings and change visibility to
**Public** so Unraid can pull without a registry login. GitHub currently exposes
this setting through its web UI, not `gh` or the supported REST API.

## Unraid

Use `unraid/compose.yml` with Compose Manager, or create an equivalent container
in Unraid's Docker UI:

- Repository: `ghcr.io/waffleophagus/sparkdash:latest`
- Network: host; the application binds only to `127.0.0.1:5555`
- Path: `/mnt/user/appdata/sparkdash` → `/app/config` (read/write)
- Variables: `BIND_HOST=127.0.0.1`, `PORT=5555`,
  `SPARKDASH_ALLOW_OPEN_REMOTE=0`
- Restart policy: `unless-stopped`

From your laptop, run:

```sh
ssh -N -L 5555:127.0.0.1:5555 root@172.16.1.100
```

Then open `http://127.0.0.1:5555`. For shared browser access, put an authenticated
HTTPS reverse proxy in front of this loopback service, including WebSocket upgrades.
Upstream currently applies its bearer middleware to static assets as well as APIs,
so a simple direct LAN bind with a token is not a complete browser login flow.
This configuration follows upstream's documented SSH-tunnel/proxy approach.

Add Spark machines as **remote** units using IPs reachable from Unraid. Optional
SSH key mounts are shown in the Compose file; passwords can also be configured
in the UI. Back up the entire appdata directory, including its generated encryption
key, to preserve encrypted credentials.

This configuration monitors remote machines. Local Unraid host/GPU monitoring
needs additional host mounts and driver integration and is not enabled here.
Loopback-only services on remote Sparks may need upstream's SSH-tunnel support.
Published images do not automatically update the running Unraid container; update
it through Unraid when ready. Use a commit tag instead of `latest` to pin a release.

Application license: upstream MIT; see `LICENSE`.
