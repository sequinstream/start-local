# 🚀 Try Sequin locally

Run Sequin and its supporting services on your local machine using a simple shell script. This setup uses [Docker](https://www.docker.com/) behind the scenes to install and run the services.

> [!IMPORTANT]  
> This script is for local testing only. Do not use it in production!
> For production installations refer to the [official Sequin documentation](https://sequinstream.com/docs).

## 🌟 Features

This script sets up a complete Sequin environment for local development and testing:

- **Sequin**: The main Sequin application
- **PostgreSQL**: Database for Sequin's internal use and sample data
- **Redis**: For caching and message processing
- **Prometheus**: For metrics collection (optional)
- **Grafana**: For metrics visualization with pre-configured dashboards (optional)

## 💻 System requirements

- [Docker](https://www.docker.com/)
- Works on Linux, macOS, and Windows with [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install)

## 🏃‍♀️‍➡️ Getting started

### Setup

Run the `start-local` script using [curl](https://curl.se/):

```bash
curl -fsSL https://sequinstream.com/start-local | sh
```

This script creates a `sequin-start-local` folder containing:

- `docker-compose.yml`: Docker Compose configuration for Sequin and its supporting services
- `.env`: Environment settings, including database passwords
- `start.sh` and `stop.sh`: Scripts to start and stop the Sequin services
- `uninstall.sh`: The script to uninstall Sequin and its services

### Select the version to install

By default, `start-local` uses the latest version of Sequin. If you want, you can specify a different version using the `-v` parameter, as follows:

```bash
curl -fsSL https://sequinstream.com/start-local | sh -s -- -v 0.6.107
```

### Install without Prometheus and Grafana

If you want to install only the core services (Sequin, PostgreSQL, and Redis) without Prometheus and Grafana, you can use the `-minimal` option as follows:

```bash
curl -fsSL https://sequin.io/start-local | sh -s -- -minimal
```

### Install without the playground database

If you want to install without the sample playground database, you can use the `-noplayground` option:

```bash
curl -fsSL https://sequin.io/start-local | sh -s -- -noplayground
```

### 🌐 Endpoints

After running the script:

- Sequin will be running at <http://localhost:7376>
- PostgreSQL will be accessible at `localhost:7377`
- Redis will be accessible at `localhost:7378`
- Prometheus will be running at <http://localhost:9090> (if installed)
- Grafana will be running at <http://localhost:3000> (if installed)

The default admin user credentials are:

- Email: `admin@sequinstream.com`
- Password: `sequinpassword!`

> [!CAUTION]
> This configuration is for local testing only. For security, services are accessible only via `localhost`.

## 🐳 Start and stop the services

You can use the `start` and `stop` commands available in the `sequin-start-local` folder.

To **stop** the Sequin Docker services, use the `stop` command:

```bash
cd sequin-start-local
./stop.sh
```

To **start** the Sequin Docker services, use the `start` command:

```bash
cd sequin-start-local
./start.sh
```

## 🗑️ Uninstallation

To remove the `start-local` installation:

```bash
cd sequin-start-local
./uninstall.sh
```

> [!WARNING]  
> This erases all data permanently.

## 📝 Logging

If the installation fails, an error log is created in `error-start-local.log`. This file contains logs from the services, captured using the [docker logs](https://docs.docker.com/reference/cli/docker/container/logs/) command.

## ⚙️ Customizing settings

To change settings, edit the `.env` file. Example contents:

```bash
SEQUIN_VERSION=latest
SEQUIN_CONTAINER_NAME=sequin-local-dev
PG_CONTAINER_NAME=postgres-local-dev
PG_PASSWORD=postgres
REDIS_CONTAINER_NAME=redis-local-dev
```

> [!IMPORTANT]
> After changing the `.env` file, restart the services using `stop` and `start`:
>
> ```bash
> cd sequin-start-local
> ./stop.sh
> ./start.sh
> ```

## 🧪 Testing the installer

We use [bashunit](https://bashunit.typeddevs.com/) to test the script. Tests are in the `/tests` folder.

### Running tests

1. Install bashunit:

   ```bash
   curl -s https://bashunit.typeddevs.com/install.sh | bash
   ```

2. Run tests:

   ```bash
   lib/bashunit
   ```

The tests run `start-local.sh` and check if Sequin and its services are working.

> [!NOTE]
> For URL pipeline testing, a local web server is used. This requires [PHP](https://www.php.net/).
