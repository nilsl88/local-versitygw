This repository provides a small set of **Compose** manifests and a helper script to run **[Versitygw](https://github.com/versity/versitygw)** (an S3-compatible gateway) backed by a local **POSIX filesystem**.

It can:
- run an S3 endpoint backed by a local folder (`./data`)
- store IAM config in `./iam`
- optionally store extra metadata in a sidecar folder (`./meta/sidecar`)
- optionally enable TLS (either in VersityGW itself or via a Caddy reverse proxy)

Default endpoints:
- **S3 API:** `http://localhost:7070`
- **Admin API:** `http://localhost:7071` (treat as sensitive)

---

## Files in this repo (what each one does)

### `docker-compose.yaml`
The **basic** setup:
- runs a single `versitygw` container
- exposes ports `7070` (S3) and `7071` (admin)
- mounts:
  - `./data` → `/data`
  - `./iam` → `/iam`

Use this when you just want the simplest local HTTP setup.

### `docker-compose-sidecar.yaml`
Same as the basic setup, but enables:
- `--sidecar /meta/sidecar`
- mounts `./meta` → `/meta`

Use this if you want VersityGW to store metadata sidecar files on disk.

### `docker-compose-certs.yaml`
Runs VersityGW with **TLS enabled inside VersityGW**:
- expects cert files in `./certs/` (mounted read-only)
  - `./certs/fullchain.pem`
  - `./certs/privkey.key`
- enables TLS for both S3 and Admin endpoints
- also enables the metadata sidecar (`./meta`)

Use this when you want HTTPS without a reverse proxy.

### `docker-compose-caddy.yaml`
Runs **VersityGW + Caddy**:
- VersityGW still runs on `7070/7071` (and is exposed)
- Caddy listens on `80/443` and proxies to VersityGW
- expects a `./Caddyfile` (mounted into Caddy)

Use this when you prefer TLS termination / routing in Caddy.

### `docker-compose-caddy-self-signed.yaml`
Same idea as the Caddy setup, but also mounts:
- `./certs` → `/certs` into Caddy (read-only)

Use this when your `Caddyfile` references self-signed/custom certs stored in `./certs`.

### `UpandRun.sh`
A convenience script that:
1) creates the local folders (`data/`, `iam/`, `meta/sidecar/`, `certs/`)
2) starts the Compose stack
3) uses the VersityGW admin CLI to create 1 admin user + 3 users
4) uses the AWS CLI container to create 3 buckets and assign ownership
5) validates each user only sees their own bucket
