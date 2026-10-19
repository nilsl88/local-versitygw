# Local VersityGW

Run [VersityGW](https://github.com/versity/versitygw) as an S3-compatible gateway backed by the local POSIX filesystem. All five Compose manifests enable the WebGUI at `/ui/` on the S3 listener with `--webui-s3-prefix /ui`. No separate WebGUI port is needed.

Objects are stored in `./data`, and gateway accounts are stored in `./iam`. Some variants also store metadata in `./meta/sidecar`.

## Choose a configuration

Each manifest is a complete setup. Start one at a time; do not merge them as Compose override files.

| Manifest | WebGUI URL with default hostname | S3 endpoint | Admin endpoint | Metadata |
| --- | --- | --- | --- | --- |
| `docker-compose.yaml` | `http://localhost:7070/ui/` | `http://localhost:7070` | `http://localhost:7071` | Filesystem xattrs |
| `docker-compose-sidecar.yaml` | `http://localhost:7070/ui/` | `http://localhost:7070` | `http://localhost:7071` | `./meta/sidecar` |
| `docker-compose-certs.yaml` | `https://localhost:7070/ui/` | `https://localhost:7070` | `https://localhost:7071` | `./meta/sidecar` |
| `docker-compose-caddy.yaml` | `https://versitygw.example.com/ui/` | `https://versitygw.example.com` | `https://versitygw.example.com/admin` | Filesystem xattrs |
| `docker-compose-caddy-self-signed.yaml` | `https://versitygw.example.com/ui/` | `https://versitygw.example.com` | `https://versitygw.example.com/admin` | `./meta/sidecar` |

The Caddy variants proxy S3 and `/ui/` to port 7070 and `/admin` to the separate admin listener on port 7071. They also publish the gateway's HTTP ports directly: S3 on `http://<hostname>:7070` and admin on `http://<hostname>:7071/admin`. These direct ports are for API/CLI clients; open the WebGUI through Caddy's HTTPS URL so the browser origin matches its CORS configuration. Restrict access to these backend ports as appropriate.

## Start the gateway

For the basic local HTTP setup:

```sh
mkdir -p data iam meta/sidecar certs
podman compose -f docker-compose.yaml pull
podman compose -f docker-compose.yaml up -d
```

Open [http://localhost:7070/ui/](http://localhost:7070/ui/). Replace `podman compose` with `docker compose` if using Docker. Use the selected manifest's filename for both commands when starting another variant. Pulling updates a cached `latest` image; the WebGUI configuration was checked against VersityGW v1.9.0.

Set `VGW_HOSTNAME` before starting a stack when the browser uses a different hostname. Use a DNS hostname or IPv4 address, without a scheme, port, or path:

```sh
export VGW_HOSTNAME=storage.example.com
podman compose -f docker-compose-sidecar.yaml up -d
```

Then open `http://storage.example.com:7070/ui/`. The manifests use this hostname for the WebGUI's S3 and admin endpoint settings and its allowed browser origin. Use the same hostname in the browser; switching between `localhost`, an IP address, and a DNS name changes the origin.

### Native TLS

Before starting `docker-compose-certs.yaml`, provide:

- `./certs/fullchain.pem`
- `./certs/privkey.key`

The WebGUI shares the S3 listener's TLS configuration. The admin listener uses the same certificate files on port 7071. The certificate must cover `VGW_HOSTNAME`, and the browser must trust its issuer for both endpoints. With the default hostname, it must cover `localhost`.

### Caddy TLS

Set `VGW_HOSTNAME` to your actual domain for either Caddy variant. Both the gateway and the mounted Caddyfile read this value.

`docker-compose-caddy.yaml` uses `Caddyfile` and Caddy's automatic HTTPS. Point the domain's DNS records at this host and make ports 80 and 443 reachable for certificate issuance and browser access.

`docker-compose-caddy-self-signed.yaml` uses `Caddyfile-self-signed` and expects:

- `./certs/fullchain.cer`
- `./certs/private.key`

These filenames differ from the native TLS variant. The certificate must cover your hostname; install its CA in the browser's trust store when using a private or self-signed certificate.

## Sign in and check access

Use access key `rootaccess` and secret key `rootsecret` for the initial login. These credentials are local examples; change the root credentials in your chosen manifest before exposing the service to other users. The browser holds the secret during the session, so use HTTPS for remote access and sign out when finished.

The login form is preconfigured with the endpoints shown above. Keep **Bucket Addressing Style** set to **Path Style**. These manifests use the gateway's built-in account store; leave the standalone IAM endpoint empty.

After login, check that the management pages load, then create a bucket and upload, download, and delete a small file in Explorer. This checks browser access to both APIs and the object backend.

`UpandRun.sh` starts the basic HTTP configuration and provisions `vadmin`/`vadminsecret` plus `user1`/`user1secret`, `user2`/`user2secret`, and `user3`/`user3secret`. It creates a bucket for each standard user and assigns ownership. Run it against a fresh basic setup. Its hardcoded HTTP endpoints are intended for that configuration, and it does not wait for gateway readiness. Inspect the final listings manually; the script does not assert isolation.

## WebGUI compatibility details

- `/ui` reserves the bucket name `ui` in every variant. The Caddy variants also reserve `admin` for the admin API path.
- The manifests set `--cors-allow-origin` to the WebGUI's browser origin. For HTTP and native TLS, this lets the browser reach the admin API on its separate port. Caddy exposes both APIs through the same HTTPS origin. If a bucket has its own CORS configuration, that configuration takes precedence over the global S3 fallback.
- Versioning controls in the WebGUI require backend support. These manifests do not configure `--versioning-dir`; add a persistent versioning directory and enable versioning on the bucket before using those controls.
- Back up `./data` and `./iam` together. For sidecar variants, include `./meta` as well; for xattr variants, preserve extended attributes when copying or restoring data.

See the upstream [WebGUI guide](https://github.com/versity/versitygw/wiki/WebGUI) for interface features and authentication details.
