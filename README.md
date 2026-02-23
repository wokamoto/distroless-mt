# distroless-mt

## Overview
- Docker Compose stack for local Movable Type development.
- Movable Type source is provided from a zip file under `files/movabletype/` during image build.
- `movabletype`, `webserver`, and related images use multi-stage Dockerfiles, and runtime containers use distroless images where configured.
- The stack includes MySQL, phpMyAdmin, and Mailpit.

## Tech Stack
- Nginx (`bin/webserver/nginx/Dockerfile`)
- Apache HTTP Server (`bin/webserver/httpd/Dockerfile`)
- Movable Type + Starman (`bin/movabletype/Dockerfile`)
- MySQL (`bin/database/mysql80/Dockerfile` or `bin/database/mysql84/Dockerfile`)
- phpMyAdmin (`phpmyadmin`)
- Mailpit (`axllent/mailpit`)

## Key Paths
- `.env`: default environment variables, ports, and image selectors
- `docker-compose.yml`: service definitions, mounts, and networking
- `Makefile`: helper targets for MT asset extraction and compose build/up/down
- `files/movabletype`: location for MT source zip (`MT_SOURCE_ZIP`)
- `www/mt-config.cgi`: Movable Type runtime configuration mounted into the container
- `www/movabletype/mt-static`: static assets extracted from MT zip by `make prepare-mt`
- `www/movabletype/plugins`: plugins extracted from MT zip by `make prepare-mt`
- `www/movabletype/mt-templates`: mounted template directory for Movable Type
- `config/nginx/nginx.conf`: top-level Nginx configuration copied into the image
- `config/nginx/conf.d/default.conf`: Nginx site and reverse-proxy rules (`/mt/` and `/mt-static/`)
- `config/httpd/httpd.conf`: Apache global configuration copied into the image
- `config/httpd/conf.d/default.conf`: Apache vhost rules (`/mt/` proxy and `/mt-static` alias)
- `config/initdb/01-mysql-native-password.sh`: DB init script to set app user auth plugin to `mysql_native_password`

## Movable Type Layout (in Container)
```text
/var/www/
├── html
│   └── htdocs            # web document root
├── movabletype           # reverse-proxied as /mt from webserver
│   ├── mt-static         # served as /mt-static
│   ├── mt-templates
│   ├── plugins
│   ├── mt-config.cgi
│   └── ...
└── movabletype.conf
```

## Local Development (Docker)
1. Put the Movable Type source zip under `files/movabletype/` and set `MT_SOURCE_ZIP` in `.env`.
2. Extract static assets and plugins: `make prepare-mt`.
3. Start (first run, or after Dockerfile/config changes): `docker compose up -d --build`
4. Open:
   - `http://localhost:8080` (site)
   - `http://localhost:8080/mt/` (Movable Type admin)
   - `http://localhost:8080/mt-static/` (static assets)
   - `http://localhost:9080` (phpMyAdmin)
   - `http://localhost:19980` (Mailpit UI)
5. Stop: `docker compose stop`

To reset persistent named volumes (`dbdata`, `mailpitdata`):
- `docker compose down -v`
- `make prepare-mt`
- `docker compose up -d --build`

Default ports in `.env`:
- HTTP: `HOST_MACHINE_UNSECURE_HOST_PORT=8080`
- HTTPS: `HOST_MACHINE_SECURE_HOST_PORT=8443`
- phpMyAdmin HTTP/HTTPS: `HOST_MACHINE_PMA_PORT=9080`, `HOST_MACHINE_PMA_SECURE_PORT=9443`
- Mailpit UI: `HOST_MACHINE_MAILPIT_PORT=19980` (`mail:1025` is available only inside the Docker network)

Database access:
- The `database` service is exposed only inside the Compose network (`expose: 3306`).
- Use service name `database:3306` from other containers, or phpMyAdmin from the host.

### Makefile Targets
- `make prepare-mt`: extract `mt-static` and `plugins` from MT zip into `www/movabletype/`
- `make build`: run `prepare-mt` then `docker compose build`
- `make up`: run `build` then `docker compose up -d`
- `make down`: run `docker compose down`
- `make help`: show target summary

### Image and Version Selection
- `WEBSERVER` selects the web server Dockerfile (`httpd`, `nginx`), default: `httpd`
- `DATABASE` selects the database Dockerfile (`mysql80`, `mysql84`), default: `mysql84`
- `MT_SOURCE_ZIP` selects the Movable Type source zip filename, default: `MT-8.8.2.zip`
- `DEPLOY_ENV` selects deployment-target image settings (`local`, `fargate`). If omitted, build arg defaults to `local`.
- After changing these values in `.env`, rebuild with `docker compose up -d --build`
- Container names are `mt-movabletype`, `mt-${WEBSERVER}`, `mt-${DATABASE}`, `mt-phpmyadmin`, and `mt-mail`
- Image tag rules (`webserver`/`movabletype`):
  - `DEPLOY_ENV` unset: base tag (e.g. `httpd`, `nginx`, `movabletype`)
  - `DEPLOY_ENV=local`: `<base>-local` (e.g. `httpd-local`)
  - `DEPLOY_ENV=fargate`: `<base>-fargate` (e.g. `httpd-fargate`)

### Fargate Image Build
To build Fargate-oriented images:
- `DEPLOY_ENV=fargate docker compose build`

When `DEPLOY_ENV=fargate`:
- Webserver -> Movable Type upstream changes to `127.0.0.1:5000` (same ECS task/sidecar use case)
- `/var/log/nginx/access.log` and `/var/log/httpd/access.log` are redirected to `STDOUT`
- `/var/log/nginx/error.log`, `/var/log/httpd/error.log`, and `/var/log/movabletype/error.log` are redirected to `STDERR`

### Mail Testing with Mailpit
To send mail to the bundled Mailpit service from containers in this stack:
- Host: `mail`
- Port: `1025`
- SMTP auth: disabled
- TLS: disabled

### HTTPS (optional)
- Put `cert.pem` and `cert-key.pem` in `config/ssl`.
- `webserver` maps host `${HOST_MACHINE_SECURE_HOST_PORT}` to container `443`.
- If using Nginx, configure an HTTPS server block in `config/nginx/conf.d/`.
- Access `https://localhost:8443`.

## Environment Notes
- DB credentials are injected through `.env` into `movabletype`, `database`, and `phpmyadmin` services.
- `movabletype` uses `MT_CONFIG_FILE`, `MT_LOG_DIR`, and template/plugin bind mounts from `.env`/Compose defaults.
- `TIME_ZONE` is an optional build argument for web/database images and defaults to `Asia/Tokyo` in Dockerfiles.
- `DEPLOY_ENV` is an optional build argument for webserver/movabletype images and defaults to `local`.
- MySQL and Mailpit data are stored in named volumes (`dbdata`, `mailpitdata`).
- Replace placeholder credentials in `.env` before any non-local use.
