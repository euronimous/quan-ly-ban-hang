# Park Việt — Installation Guide

```
Host machine:  MySQL 5.7
Docker:        Rails app + Webpack + Redis + Elasticsearch
Browser:       http://localhost:3000
```

Only **two** things are installed on your machine: Docker Desktop and MySQL.
Everything else (Rails, Redis, Elasticsearch) runs inside Docker.

---

## Step 1 — Install Docker Desktop

Download and install from https://www.docker.com/products/docker-desktop

- **Mac:** drag to Applications, start it, wait for the whale icon in the menu bar
- **Windows 11:** run the installer, restart, accept the WSL2 setup when prompted

Verify (open a terminal / PowerShell):
```bash
docker --version    # Docker version 24.x or later
docker compose version
```

> Make sure Docker Desktop is **running** (whale icon present) before starting the app.

---

## Step 2 — Install MySQL 5.7

### Mac
```bash
brew install mysql@5.7
brew link mysql@5.7 --force
brew services start mysql@5.7
```

Set the root password to match `config/database.yml`:
```bash
mysql -u root
```
```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'thuy425';
FLUSH PRIVILEGES;
EXIT;
```

### Windows 11

1. Download **MySQL Community Server 5.7** from https://dev.mysql.com/downloads/mysql/5.7.html
2. Run the installer → choose **Developer Default** → follow the wizard
3. Set the root password to `thuy425` when prompted
4. MySQL installs as a Windows service named **MySQL57** and starts automatically

---

## Step 3 — Clone the project

```bash
git clone <repo-url> parkviet
cd parkviet
```

---

## Step 4 — Start the app (one command)

### Mac / Linux
```bash
chmod +x start.sh
./start.sh
```

### Windows 11
Double-click **`start.bat`**

> First run takes ~5–10 minutes: it builds the Docker image, pulls Redis +
> Elasticsearch, and sets up the database. Later runs start in seconds.

Open http://localhost:3000 in your browser.

---

## First login

Go to http://localhost:3000/dang-ky to register and create your store.

---

## Daily workflow

| Task | Command |
|---|---|
| Start app | `./start.sh` (Mac) · double-click `start.bat` (Windows) |
| Stop app | `Ctrl+C`, then `docker compose stop` |
| Rails console | `docker compose exec web bundle exec rails console` |
| Run migrations | `docker compose exec web bundle exec rails db:migrate` |
| View app logs | `docker compose logs -f web` |
| Rebuild after Gemfile change | `docker compose build` |
| Full reset (wipe Redis/ES data) | `docker compose down -v` |

---

## How it connects

The app talks to each service differently:

| Service | Where | App connects via |
|---|---|---|
| MySQL | Host | `host.docker.internal:3306` |
| Redis | Docker | `redis:6379` (service name) |
| Elasticsearch | Docker | `elasticsearch:9200` (service name) |

These are wired up automatically through environment variables in `docker-compose.yml` — you don't need to configure anything.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `db:create failed` / `Can't connect to MySQL` | Ensure MySQL is running and the root password is `thuy425`. Test: `mysql -u root -pthuy425` |
| Windows: MySQL connection refused from Docker | MySQL must accept network connections. In `my.ini` ensure `bind-address` is `0.0.0.0` (or commented out), then restart the MySQL57 service |
| Mac: MySQL refuses Docker connection | Edit `/opt/homebrew/etc/my.cnf`, set `bind-address = 0.0.0.0`, then `brew services restart mysql@5.7` |
| `Docker is not running` | Open Docker Desktop and wait for the whale icon |
| Elasticsearch container keeps restarting | Give Docker Desktop more RAM (Settings → Resources → ≥ 4 GB) |
| Port 3000 already in use | Stop the other process, or change the port mapping in `docker-compose.yml` |
| Want a clean slate | `docker compose down -v` then delete `tmp/.setup_done` and re-run the start script |
