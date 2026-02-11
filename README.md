# distroless-mt

## Overview
- Docker Compose stack for running **Movable Type** locally.
- Web server and application images use multi-stage builds and run on `gcr.io/distroless/base-debian13`.
- The stack includes MySQL, phpMyAdmin, and Mailpit.

## Tech Stack
- Apache HTTP Server 2.4 (`bin/apache24/Dockerfile`)
- Nginx 1.29 (`bin/nginx/Dockerfile`)
- Movable Type (Perl/Starman) (`bin/movabletype/Dockerfile`)
- MySQL (`bin/mysql80/Dockerfile` or `bin/mysql84/Dockerfile`)
- phpMyAdmin (`phpmyadmin`)
- Mailpit (`axllent/mailpit`)

## Key Paths
- `.env`: default environment variables, ports, and image selectors
- `Makefile`: targets for extracting MT static files and building (see below)
- `docker-compose.yml`: service definitions, mounts, and networking
- `bin/movabletype/`: Movable Type image (Perl 5.42, Starman, MT 8.8.2); see `README-DBD-mysql.md` for DB driver notes
- `files/movabletype/`: MT source zip directory (filename is set by `MT_SOURCE_ZIP` in `.env`, e.g. `MT-8.8.2.zip`)
- `www/mt-config.cgi`: MT config (mounted into the container)
- `www/movabletype/mt-static`, `www/movabletype/plugins`: MT static assets and plugins (populated by `make prepare-mt`)
- `logs/movabletype/`: MT error log (mounted from the container)
- `config/php/php.ini`: PHP configuration for phpMyAdmin
- `config/httpd/httpd.conf`, `config/httpd/conf.d/default.conf`: Apache configuration (when `WEBSERVER=apache24`)
- `config/nginx/nginx.conf`, `config/nginx/conf.d/`: Nginx configuration
- `config/nginx/conf.d/default-ssl.conf`: optional HTTPS server block template

## Important: Add Movable Type Source ZIP
- Movable Type source code is **not** included in this repository.
- Set `MT_SOURCE_ZIP` in `.env` (example: `MT_SOURCE_ZIP=MT-8.8.2.zip`).
- Place that ZIP file under `files/movabletype/` before running `make prepare-mt` or `docker compose up --build`.

## Before First Run: Extract MT static files

**You must run `make prepare-mt` before the first build** so that `www/movabletype/mt-static` and `www/movabletype/plugins` are filled from the MT zip. Without this, `/mt-static` and plugin assets will return 404.

```bash
make prepare-mt
```

This extracts `mt-static` and `plugins` from `files/movabletype/${MT_SOURCE_ZIP}` (`MT_SOURCE_ZIP` in `.env`) into `www/movabletype/`. Re-run it when you change the MT zip (e.g. after upgrading the zip file).

## Movable Type Directory Layout (Inside Container)
```text
/var/www/
├── html
│   └── htdocs            # Web document root
├── movabletype           # Reverse-proxied as /mt; origin is movabletype:9000
│   ├── mt-static         # Alias /mt-static
│   ├── mt-templates
│   ├── plugins
│   ├── mt-config.cgi
│   └── ...
└── movabletype.conf
```

## Local Development (Docker)
1. **Extract MT static files** (if not done yet): `make prepare-mt`
2. Start (first run, or after Dockerfile/config changes): `docker compose up -d --build`  
   Or use the Makefile: `make build` (runs `prepare-mt` then `docker compose build`), then `docker compose up -d`; or `make up` to do both.
3. Access:
   - `http://localhost:8080` — site (MT behind the webserver)
   - `http://localhost:8080/mt/` — MT admin
   - `http://localhost:8080/mt/admin` — MT dashboard
   - `http://localhost:8080/mt-static/` — MT static assets
   - `http://localhost:9080` (phpMyAdmin)
   - `http://localhost:19980` (Mailpit UI)
4. Stop: `docker compose stop` or `make down`

To reset the persistent `mtdata` volume:
- `docker compose down -v`
- `make prepare-mt` (optional, if you want to refresh static files)
- `docker compose up -d --build`

### Makefile targets
- `make prepare-mt` — Extract mt-static and plugins from the MT zip into `www/movabletype/`
- `make build` — Run `prepare-mt` then `docker compose build`
- `make up` — Run `build` then `docker compose up -d`
- `make down` — Run `docker compose down`
- `make help` — Show targets

Set zip filename in `.env`: `MT_SOURCE_ZIP=MT-9.0.0.zip`  
Temporary override: `make MT_ZIP=path/to/MT-9.0.0.zip prepare-mt`

Default ports in `.env`:
- HTTP: `HOST_MACHINE_UNSECURE_HOST_PORT=8080`
- HTTPS: `HOST_MACHINE_SECURE_HOST_PORT=8443`
- phpMyAdmin: `HOST_MACHINE_PMA_PORT=9080`, `HOST_MACHINE_PMA_SECURE_PORT=9443`
- Mailpit UI: `HOST_MACHINE_MAILPIT_PORT=19980` (SMTP `mail:1025` is available inside the Docker network only)

Database access:
- The `database` service is exposed only inside the Compose network (`expose: 3306`).
- Use service name `database:3306` from other containers, or phpMyAdmin from the host.

### Image and Version Selection
- `DATABASE` selects the database Dockerfile (`mysql80`, `mysql84`), default: `mysql84`
- `WEBSERVER` selects the web server image (`apache24`, `nginx`), default: `apache24`
- After changing these in `.env`, rebuild with `docker compose up -d --build`
- `docker ps` shows the active web server container name (e.g. `local-mt-apache24` or `local-mt-nginx`)

### Mail Testing with Mailpit
To send mail to the bundled Mailpit from an application in the stack:
- SMTP host: `mail`
- Port: `1025`
- No authentication, no TLS

### HTTPS (optional)
- Put `cert.pem` and `cert-key.pem` in `config/ssl`.
- For Nginx, uncomment the HTTPS server block in `config/nginx/conf.d/default-ssl.conf`.
- Access `https://localhost:8443`.

## Environment Notes
- DB credentials are set via `.env` and injected into services.
- Log directories are configurable in `.env` (`NGINX_LOG_DIR`, `HTTPD_LOG_DIR`, `MYSQL_LOG_DIR`, `MT_LOG_DIR`).
- MT config path: `MT_CONFIG_FILE` (default `./www/mt-config.cgi`).
- Replace any placeholder secrets in `.env` before non-local use.
