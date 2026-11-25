# devenv-murz — agent notes

Read `README.md` first. This file records constraints that are easy to break.

## What this directory is

Two artifacts in one folder:

1. A container image (`Dockerfile` at the repo root of this chart). Published as `ghcr.io/murznn/devenv-murz:latest`.
2. A Helm application chart in `helm/` that runs that image. It does not vendor Kubernetes manifests. `helm/templates/common.yaml` only calls the bjw-s common library (`oci://ghcr.io/bjw-s-labs/helm`, chart `common` 5.3.0). All workload shape lives in `helm/values.yaml`.

Parent repo context: `mrk-services` is a Helmwave project. For app-template behavior, use the `deepwiki` MCP on `bjw-s-labs/helm-charts`, or read `deps/helm-charts` and `deps/helm-charts/docs/src/content/docs/app-template` at the mrk-services root. Values schema comment in `values.yaml` points at `charts/library/common/values.schema.json`.

## Do not "fix" these

- **SSH host key mode.** `fsGroup: 1000` makes kubelet widen Secret files (`0600` → `0640`). `sshd` rejects a group-readable host key. The Secret stays at `/mnt/ssh-host-key` (read-only). `/entrypoint.sh` copies it to `/home/developer/.ssh/ssh_host_key` with `install -m 600`. Do not mount the Secret straight onto `~/.ssh/ssh_host_key`.
- **Host key stability.** `templates/ssh-host-key-secret.yaml` uses `lookup` and reuses `data.ssh_host_key` when the Secret already exists. Replacing this with a plain `genPrivateKey` on every render rotates the key and breaks known_hosts. `lookup` is empty on `helm template`; that is expected.
- **Non-root sshd.** User is uid 1000. `sshd_config` `Port` must stay above 1024. Current port is 2222, matching Service `sshd.ports.ssh.port`.
- **ConfigMap names.** `configMapsFromFolder` with `basePath: files/configMaps` produces `{{ .Release.Name }}-devenv-<folder>`. Volume `volumeSpec.configMap.name` values (`devenv-supervisor`, `devenv-sshd`, `devenv-bash`) must keep matching those folder names. File names inside the folders are the ConfigMap keys and the `subPath`s.
- **User identity.** The image renames the upstream `node` user to `developer` and moves home to `/home/developer`. Chart `runAsUser`/`runAsGroup`/`fsGroup` and entrypoint `chown 1000` assume that uid. Paths in values (`/home/developer/.ssh`, `.cache`, `.yarn`, `.pnpm`, `.cursor`, `.cursor-server`) must stay aligned with `USERNAME` / `HOME` in the Dockerfile.
- **Probes off.** `supervisord` is the PID 1 process and does not speak HTTP. Leave liveness, readiness, and startup disabled unless you add a real probe endpoint.
- **nodePort `777`.** Both `sshd` and `et` set `nodePort: 777` as a placeholder that is invalid as a real NodePort (range is 30000–32767) and duplicated. Releases override it. Do not treat `777` as a working default.

## Processes

Supervisor config in the image (`/etc/supervisor/supervisord.conf`) includes:

- `/etc/supervisor/conf.d/*.conf` — chart file `files/configMaps/supervisor/services.conf` (`sshd`, `cursor-agent`)
- `/app/deploy/supervisor/*.conf` — optional extra programs from the `/app` PVC; nothing in this repo ships them

`cursor-agent` runs `/home/developer/.local/bin/agent worker start` (installed via `curl https://cursor.com/install`). `.bashrc` aliases: `s` / `ss` / `sr` / `logs` → `supervisorctl`.

Login shells (SSH, `su -`) source `/etc/profile.d/container_env.sh`, which the entrypoint rebuilds from `env` on every start. Interactive non-login bash uses the mounted `.bashrc`.

## Persistence map

| PVC | Survives pod restart | What belongs here |
|---|---|---|
| `app` (3Gi) | `/app` | project checkout, `/app/deploy/supervisor/*.conf` |
| `user` (1Gi) | `/user`, `/home/developer/.ssh` | `authorized_keys`, the copied host key, sshd pid file |
| `cache` (10Gi) | `/cache` and tool subPaths | yarn, pnpm, Cursor state |

ConfigMap and Secret mounts are not on those PVCs. Changing a file under `helm/files/configMaps/` only takes effect after Helm upgrade (and a pod restart, because they are mounted files).

## Consumers and image tag

- Subchart of `charts/plc-dev` as dependency `devenv` (`alias: devenv`, `file://../devenv-murz/helm`, version `1.0.0`). A packed copy may exist at `charts/plc-dev/charts/devenv-murz-1.0.0.tgz`; bumping this chart's version requires updating that dependency and re-vendoring.
- Helmwave release `plc-dk` uses `./charts/plc-dev`, not this chart directly. `helmwave.yml` has a commented `# chart: ./charts/devenv-murz/helm`.
- Chart default image repository is `ghcr.io/murznn/devenv-murz`, tag `latest`, `pullPolicy: Always`. CI pushes `:latest` only, on push to `main`, from `.github/workflows/deploy-image.yml`. The workflow lowercases `github.repository` for the GHCR path.

## Local checks

```bash
./run.sh
docker build --progress=plain -t devenv-murz .
helm template test ./helm
```

`helm/charts/*.tgz` is gitignored; `Chart.lock` is committed. `helm dependency build` in `helm/` before template if `charts/common-*.tgz` is missing.
