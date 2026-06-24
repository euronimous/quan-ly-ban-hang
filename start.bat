@echo off
:: Park Viet — Windows 11 one-click start
:: Host:   MySQL 5.7 (Windows service)
:: Docker: Rails app + Webpack + Redis + Elasticsearch

title Park Viet

:: change to the folder where this bat file lives
cd /d "%~dp0"

echo.
echo  === Park Viet ===
echo  Working directory: %CD%
echo.

:: ── Check Docker Desktop ──────────────────────────────────────────────────────
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [ERROR] Docker Desktop is not running.
    echo  Start Docker Desktop from the Start menu, wait for the whale icon, then try again.
    pause & exit /b 1
)
echo  [OK] Docker is running

:: ── MySQL (host Windows service) ──────────────────────────────────────────────
echo  Starting MySQL...
net start MySQL57 >nul 2>&1
if %ERRORLEVEL% neq 0 (
    net start MySQL >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo        MySQL already running or service not found -- continuing
    )
)
echo  [OK] MySQL

:: ── Build Docker image if not yet built ───────────────────────────────────────
docker image inspect parkviet-web >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo  Building Docker image for the first time. This takes 5-10 minutes...
    docker compose build
    if %ERRORLEVEL% neq 0 (
        echo  [ERROR] Docker build failed. Check the output above.
        pause & exit /b 1
    )
    echo  [OK] Image built
)

:: ── First-time database setup ─────────────────────────────────────────────────
if not exist "tmp" mkdir tmp
if not exist "tmp\.setup_done" (
    echo.
    echo  Setting up database for the first time...
    echo  (this starts Redis + Elasticsearch in Docker too)

    docker compose run --rm web bundle exec rails db:create RAILS_ENV=development
    if %ERRORLEVEL% neq 0 ( echo  [ERROR] db:create failed - is MySQL running with password thuy425? & pause & exit /b 1 )

    docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=development
    if %ERRORLEVEL% neq 0 ( echo  [ERROR] db:migrate failed & pause & exit /b 1 )

    docker compose run --rm web bundle exec rails db:seed RAILS_ENV=development

    docker compose run --rm web /bin/bash -c "mysql -h host.docker.internal -u root -pthuy425 ParkViet_development < db/diadanh_2018-05-05.sql"

    docker compose run --rm web bundle exec rails runner "Chewy.strategy(:atomic){ ProductsIndex.reset!; CustomersIndex.reset!; SuppliersIndex.reset! }" RAILS_ENV=development
    if %ERRORLEVEL% neq 0 ( echo  [WARNING] Elasticsearch index build failed -- search may not work )

    type nul > "tmp\.setup_done"
    echo  [OK] Database ready
) else (
    docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=development >nul 2>&1
)

:: ── Launch ────────────────────────────────────────────────────────────────────
echo.
echo  ============================================
echo   Open http://localhost:3000 in your browser
echo   Press Ctrl+C to stop
echo  ============================================
echo.

docker compose up
