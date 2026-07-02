# Cyber Elements

A static kinetic showcase page for cyber security building blocks.

## Run locally

Use any static file server from the repository root:

```bash
python3 -m http.server 4173
```

Open `http://localhost:4173`.

## Deploy

Upload these files to any static host:

- `index.html`
- `styles.css`
- `main.js`
- `favicon.svg`

For Nginx or Caddy, point the site root at this directory. No Node.js runtime is required.

## One-command server deployment

The deployment script targets Ubuntu/Debian servers with Nginx.

DNS must already point your domain to the server before requesting HTTPS.

```bash
chmod +x scripts/deploy-nginx.sh
./scripts/deploy-nginx.sh example.com admin@example.com
```

Use HTTP only by omitting the email:

```bash
./scripts/deploy-nginx.sh example.com
```

Bind both apex and `www`:

```bash
INCLUDE_WWW=1 ./scripts/deploy-nginx.sh example.com admin@example.com
```

Defaults can be overridden:

```bash
REPO_URL=https://github.com/zachary9757/cyber-elements.git \
SITE_DIR=/var/www/cyber-elements \
SITE_NAME=cyber-elements \
./scripts/deploy-nginx.sh example.com admin@example.com
```
