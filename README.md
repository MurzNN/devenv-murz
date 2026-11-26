# devenv-node

A personal Node.js development environment packaged as a container image and a Helm chart. The image runs as user `developer` (uid/gid 1000) and starts `sshd` and the Cursor agent worker under Supervisor. The chart deploys that image as a StatefulSet with persistent home, project, and cache volumes.

Image: `ghcr.io/murznn/devenv-node:latest` (built from the repo root `Dockerfile`).

## Layout

```
devenv-node/
  Dockerfile                          # image: node:24-trixie + tools + entrypoint
  run.sh                              # local build, then docker exec into a detached container
  .github/workflows/deploy-image.yml  # push to main → build and push :latest to GHCR
  helm/
    Chart.yaml                        # application chart; library dep bjw-s common 5.3.0
    Chart.lock
    charts/common-5.3.0.tgz
    values.yaml                       # the whole workload (controllers, services, PVCs, mounts)
    templates/
      common.yaml                     # bjw-s loader: init + generate
      ssh-host-key-secret.yaml        # ed25519 host key, created once and kept across upgrades
    files/configMaps/                 # rendered by configMapsFromFolder
      supervisor/services.conf        # sshd + cursor-agent
      sshd/sshd_config
      bash/.bashrc
```

`helm/templates/common.yaml` does not define resources itself. It calls `bjw-s.common.loader.generate`, which turns `values.yaml` into a StatefulSet, Services, Ingress, ConfigMaps, and PVCs. Values schema: [bjw-s common](https://bjw-s-labs.github.io/helm-charts/docs/app-template/).

## Runtime

`/entrypoint.sh` (written in the Dockerfile):

1. Writes container env vars to `/etc/profile.d/container_env.sh` so SSH and `su -` login shells see them.
2. Fixes `/home/developer/.ssh` to `0700` owned by `1000:1000`.
3. If `/mnt/ssh-host-key/ssh_host_key` exists, copies it to `/home/developer/.ssh/ssh_host_key` with mode `0600`.
4. Execs `supervisord` in the foreground (`nodaemon=true`).

Supervisor loads `/etc/supervisor/conf.d/*.conf` and `/app/deploy/supervisor/*.conf`. The chart mounts `services.conf` as `/etc/supervisor/conf.d/services.conf`:

| Program | Command |
|---|---|
| `sshd` | `/usr/sbin/sshd -D -e -f /home/developer/.ssh/sshd_config` |
| `cursor-agent` | `/home/developer/.local/bin/agent worker start` |

`sshd_config` listens on port **2222** (unprivileged), public-key only, host key `~/.ssh/ssh_host_key`, authorized keys `~/.ssh/authorized_keys`.

### Image contents

Base `node:24-trixie`. The `node` user is renamed to `developer` and its home moved to `/home/developer`. Passwordless sudo. Global tools: `pnpm` (corepack), `@antfu/ni`, `@nubjs/nub`, [bin](https://github.com/marcosnils/bin) installing Helm, Helmwave, GitHub CLI, lnav, plus kubectl, APM, and the Cursor agent. Apt: sudo, OpenSSH client/server, Eternal Terminal (`et`), supervisor, git, ripgrep, mc, htop, telnet, traceroute, mtr.

`PATH` includes `$HOME/.local/bin` and `$HOME/.local/share/pnpm/bin`. Workdir is `/app`.

## Helm chart

Controller `main` is a StatefulSet. Probes are off. `securityContext` is `runAsUser`/`runAsGroup`/`fsGroup` 1000 with `fsGroupChangePolicy: OnRootMismatch`. `NODE_ENV=development`. Image pull policy is `Always`.

Services:

| Name | Type | Port | Notes |
|---|---|---|---|
| `main` | ClusterIP | 3030 (`http`) | app port |
| `sshd` | NodePort | 2222 | `nodePort` is a placeholder (`777`); override per release |
| `et` | NodePort | 2022 | same placeholder |

Ingress `main` is enabled with the `letsencrypt` ClusterIssuer. `hosts` and `tls.hosts` are empty and must be set by the parent chart or release values.

`configMapsFromFolder` reads `helm/files/configMaps/<name>/` and creates ConfigMaps named `{{ .Release.Name }}-devenv-<name>`.

Persistence (ReadWriteOnce):

| Volume | Size | Mounts |
|---|---|---|
| `app` | 3Gi | `/app` |
| `user` | 1Gi | `/user`, `/home/developer/.ssh` (subPath `.ssh`) |
| `cache` | 10Gi | `/cache`, and subPaths for `.cache`, `.yarn`, `.pnpm`, `.cursor`, `.cursor-server` |
| `supervisor`, `ssh`, `bash` | ConfigMaps | `services.conf`, `sshd_config`, `.bashrc` |
| `ssh-host-key` | Secret, read-only | `/mnt/ssh-host-key` |

### SSH host key

`ssh-host-key-secret.yaml` looks up Secret `<fullname>-ssh-host-key`. If `ssh_host_key` is already there it is reused; otherwise Helm generates an ed25519 key (`genPrivateKey`). That keeps the host key stable across upgrades.

The Secret is not mounted directly onto `~/.ssh`. With `fsGroup: 1000`, kubelet ORs `0040` onto volume files, so a `0600` key becomes `0640` and `sshd` refuses it. The chart mounts the Secret at `/mnt/ssh-host-key`, and the entrypoint installs a `0600` copy onto the user PVC.

## How it is deployed

This directory is not a Helmwave release by itself. `charts/plc-dev` depends on it as subchart `devenv` (`file://../devenv-node/helm`). The `plc-dk` release in `helmwave.yml` installs `charts/plc-dev`.

## Local image

From this directory:

```bash
./run.sh
# or
docker build --progress=plain -t devenv-node . && docker run -it --rm devenv-node bash
```

`./run.sh` builds, starts a detached container named `devenv-node-run`, and attaches a shell. The container stops when the shell exits.

CI (`.github/workflows/deploy-image.yml`) runs on push to `main`: `docker build` and `docker push` of `ghcr.io/<lowercase-repo>:latest`.
