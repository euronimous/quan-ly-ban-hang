@echo off
:: Park Viet — Windows 11 one-click start
:: Host:   MySQL 5.7 (Windows service)
:: Docker: Rails app + Webpack + Redis + Elasticsearch

title Park Viet
cd /d "%~dp0"

echo.
echo  === Park Viet ===
echo  Working directory: %CD%
echo.

:: ── Check Docker Desktop ──────────────────────────────────────────────────────
docker info >nul 2>&1
if errorlevel 1 goto :no_docker
echo  [OK] Docker is running

:: ── MySQL (host Windows service) ──────────────────────────────────────────────
echo  Starting MySQL...
net start MySQL80 >nul 2>&1
if errorlevel 1 net start MySQL57 >nul 2>&1
if errorlevel 1 net start MySQL >nul 2>&1
echo  [OK] MySQL (started or already running)

:: ── Build image (uses cache; fast after the first time) ───────────────────────
echo.
echo  Building Docker image (first time ~5-10 min, instant once cached)...
docker compose build
if errorlevel 1 goto :build_failed
echo  [OK] Image ready

:: ── First-time database setup ─────────────────────────────────────────────────
if not exist "tmp" mkdir tmp
if exist "tmp\.setup_done" goto :launch

echo.
echo  First-time database setup (also starts Redis + Elasticsearch)...

docker compose run --rm web bundle exec rails db:create RAILS_ENV=development
if errorlevel 1 goto :db_failed

docker compose run --rm web bundle exec rails db:migrate RAILS_ENV=development
if errorlevel 1 goto :db_failed

docker compose run --rm web bundle exec rails db:seed RAILS_ENV=development

echo  Importing provinces/districts/communes...
docker compose run --rm web /bin/bash -c "mysql -h host.docker.internal -u root -pthuy425 ParkViet_development < db/diadanh_2018-05-05.sql"

echo  Building Elasticsearch indexes...
docker compose run --rm web bundle exec rails runner "Chewy.strategy(:atomic){ ProductsIndex.reset!; CustomersIndex.reset!; SuppliersIndex.reset! }" RAILS_ENV=development
if errorlevel 1 echo  [WARNING] Elasticsearch index build failed -- search may not work

type nul > "tmp\.setup_done"
echo  [OK] Database ready

:: ── Launch ────────────────────────────────────────────────────────────────────
:launch
echo.
echo  ============================================
echo   Open http://localhost:3000 in your browser
echo   Press Ctrl+C to stop
echo  ============================================
echo.
docker compose up
goto :eof

:: ── Error handlers ────────────────────────────────────────────────────────────
:no_docker
echo  [ERROR] Docker Desktop is not running.
echo  Start Docker Desktop, wait for the whale icon, then run this again.
pause
exit /b 1

:build_failed
echo  [ERROR] Docker build failed. Scroll up to see the real error.
pause
exit /b 1

:db_failed
echo  [ERROR] Database setup failed.
echo  Most likely MySQL is not reachable. Check:
echo    1. MySQL service is running
echo    2. root password is thuy425  (test: mysql -u root -pthuy425)
echo    3. MySQL accepts network connections (bind-address = 0.0.0.0 in my.ini)
pause
exit /b 1
