#!/bin/sh
# --------------------------------------------------------
# Run Sequin and supporting services for local testing
# Note: do not use this script in a production environment
# --------------------------------------------------------
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
set -eu

parse_args() {
  # Parse the script parameters
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -v)
        # Check that there is another argument for the version
        if [ $# -lt 2 ]; then
          echo "Error: -v requires a version value (eg. -v 1.2.3)"
          exit 1
        fi
        sequin_version="$2"
        shift 2
        ;;

      -minimal)
        minimal=true
        shift
        ;;

      -noplayground)
        noplayground=true
        shift
        ;;

      --)
        # End of options; shift and exit the loop
        shift
        break
        ;;

      -*)
        # Unknown or unsupported option
        echo "Error: Unknown option '$1'"
        exit 1
        ;;

      *)
        # We've hit a non-option argument; stop parsing options
        break
        ;;
    esac
  done
}

startup() {
  echo
  echo '   _____                  _       '
  echo '  / ____|                (_)      '
  echo ' | (___   ___  __ _ _   _ _ _ __  '
  echo '  \___ \ / _ \/ _` | | | | | '_ \ '
  echo '  ____) |  __/ (_| | |_| | | | | |'
  echo ' |_____/ \___|\__, |\__,_|_|_| |_|'
  echo '                 | |              '
  echo '                 |_|              '
  echo '-------------------------------------------------'
  echo '🚀 Run Sequin for local testing'
  echo '-------------------------------------------------'
  echo 
  echo 'ℹ️  Do not use this script in a production environment'
  echo

  # Version
  version="0.1.0"

  # Folder name for the installation
  installation_folder="sequin-start-local"
  # Name of the error log
  error_log="error-start-local.log"
  # Minimum version for docker-compose
  min_docker_compose="1.29.0"
  # Container names
  sequin_container_name="sequin-local-dev"
  postgres_container_name="postgres-local-dev"
  redis_container_name="redis-local-dev"
  prometheus_container_name="prometheus-local-dev"
  grafana_container_name="grafana-local-dev"
}

# Function to check if the format is a valid semantic version (major.minor.patch)
is_valid_version() {
  echo "$1" | grep -E -q '^[0-9]+\.[0-9]+\.[0-9]+$'
}

# Get linux distribution
get_os_info() {
  if [ -f /etc/os-release ]; then
      # Most modern Linux distributions have this file
      . /etc/os-release
      echo "Distribution: $NAME"
      echo "Version: $VERSION"
  elif [ -f /etc/lsb-release ]; then
      # For older distributions using LSB (Linux Standard Base)
      . /etc/lsb-release
      echo "Distribution: $DISTRIB_ID"
      echo "Version: $DISTRIB_RELEASE"
  elif [ -f /etc/debian_version ]; then
      # For Debian-based distributions without os-release or lsb-release
      echo "Distribution: Debian"
      echo "Version: $(cat /etc/debian_version)"
  elif [ -f /etc/redhat-release ]; then
      # For Red Hat-based distributions
      echo "Distribution: $(cat /etc/redhat-release)"
  elif [ -n "${OSTYPE+x}" ]; then
    if [ "${OSTYPE#darwin}" != "$OSTYPE" ]; then
        # macOS detection
        echo "Distribution: macOS"
        echo "Version: $(sw_vers -productVersion)"
    elif [ "$OSTYPE" = "cygwin" ] || [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "win32" ]; then
        # Windows detection in environments like Git Bash, Cygwin, or MinGW
        echo "Distribution: Windows"
        echo "Version: $(cmd.exe /c ver | tr -d '\r')"
    elif [ "$OSTYPE" = "linux-gnu" ] && uname -r | grep -q "Microsoft"; then
        # Windows Subsystem for Linux (WSL) detection
        echo "Distribution: Windows (WSL)"
        echo "Version: $(uname -r)"
    fi
  else
      echo "Unknown operating system"
  fi
  if [ -f /proc/version ]; then
    # Check if running on WSL2 or WSL1 for Microsoft
    if grep -q "WSL2" /proc/version; then
      echo "Running on WSL2"
    elif grep -q "microsoft" /proc/version; then
      echo "Running on WSL1"
    fi
  fi
}

# Check if a command exists
available() { command -v "$1" >/dev/null; }

# Revert the status, removing containers, volumes, network and folder
cleanup() {
  if [ -d "./../$folder_to_clean" ]; then
    if [ -f "docker-compose.yml" ]; then
      $docker_clean >/dev/null 2>&1
      $docker_remove_volumes >/dev/null 2>&1
    fi
    cd ..
    rm -rf "${folder_to_clean}"
  fi
}

# Generate the error log
# parameter 1: error message
# parameter 2: the container names to retrieve, separated by comma
generate_error_log() {
  msg="$1"
  docker_services="$2"
  error_file="$error_log"
  if [ -d "./../$folder_to_clean" ]; then
    error_file="./../$error_log"
  fi
  if [ -n "${msg}" ]; then
    echo "${msg}" > "$error_file"
  fi
  { 
    echo "Start-local version: ${version}"
    echo "Docker engine: $(docker --version)"
    echo "Docker compose: ${docker_version}"
    get_os_info
  } >> "$error_file" 
  for service in $docker_services; do
    echo "-- Logs of service ${service}:" >> "$error_file"
    docker logs "${service}" >> "$error_file" 2> /dev/null
  done
  echo "An error log has been generated in ${error_log} file."
  echo "If you need assistance, open an issue at https://github.com/sequinstream/sequin/issues"
}

# Compare versions
# parameter 1: version to compare
# parameter 2: version to compare
compare_versions() {
  v1=$1
  v2=$2

  original_ifs="$IFS"
  IFS='.'
  # shellcheck disable=SC2086
  set -- $v1; v1_major=${1:-0}; v1_minor=${2:-0}; v1_patch=${3:-0}
  IFS='.'
  # shellcheck disable=SC2086
  set -- $v2; v2_major=${1:-0}; v2_minor=${2:-0}; v2_patch=${3:-0}
  IFS="$original_ifs"

  [ "$v1_major" -lt "$v2_major" ] && echo "lt" && return 0
  [ "$v1_major" -gt "$v2_major" ] && echo "gt" && return 0

  [ "$v1_minor" -lt "$v2_minor" ] && echo "lt" && return 0
  [ "$v1_minor" -gt "$v2_minor" ] && echo "gt" && return 0

  [ "$v1_patch" -lt "$v2_patch" ] && echo "lt" && return 0
  [ "$v1_patch" -gt "$v2_patch" ] && echo "gt" && return 0

  echo "eq"
}

# Wait for availability of Sequin health endpoint
# parameter: timeout in seconds
wait_for_sequin() {
  timeout="${1:-60}"
  echo "- Waiting for Sequin to be ready"
  echo
  start_time="$(date +%s)"
  until curl -s http://localhost:7376/health | grep -q '"ok":true'; do
    elapsed_time="$(($(date +%s) - start_time))"
    if [ "$elapsed_time" -ge "$timeout" ]; then
      error_msg="Error: Sequin timeout of ${timeout} sec"
      echo "$error_msg"
      generate_error_log "${error_msg}" "${sequin_container_name} ${postgres_container_name} ${redis_container_name}"
      cleanup
      exit 1
    fi
    sleep 2
  done
}

# Check if a container is runnning
# parameter: the name of the container
check_container_running() {
  container_name=$1
  containers="$(docker ps --format '{{.Names}}')"
  if echo "$containers" | grep -q "^${container_name}$"; then
    echo "The docker container '$container_name' is already running!"
    echo "You can have only one running at time."
    echo "To stop the container run the following command:"
    echo
    echo "docker stop $container_name"
    exit 1
  fi
}

check_requirements() {
  # Check the requirements
  if ! available "curl"; then
    echo "Error: curl command is required"
    echo "You can install it from https://curl.se/download.html."
    exit 1
  fi
  if ! available "grep"; then
    echo "Error: grep command is required"
    echo "You can install it from https://www.gnu.org/software/grep/."
    exit 1
  fi
  need_wait_for_sequin=true
  # Check for "docker compose" or "docker-compose"
  set +e
  if ! docker compose >/dev/null 2>&1; then
    if ! available "docker-compose"; then
      if ! available "docker"; then
        echo "Error: docker command is required"
        echo "You can install it from https://docs.docker.com/engine/install/."
        exit 1
      fi
      echo "Error: docker compose is required"
      echo "You can install it from https://docs.docker.com/compose/install/"
      exit 1
    fi
    docker="docker-compose up -d"
    docker_stop="docker-compose stop"
    docker_clean="docker-compose rm -fsv"
    docker_remove_volumes="docker-compose down -v"
    docker_version=$(docker-compose --version | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    if [ "$(compare_versions "$docker_version" "$min_docker_compose")" = "lt" ]; then
      echo "Unfortunately we don't support docker compose ${docker_version}. The minimum required version is $min_docker_compose."
      echo "You can migrate you docker compose from https://docs.docker.com/compose/migrate/"
      cleanup
      exit 1
    fi 
  else
    docker_stop="docker compose stop"
    docker_clean="docker compose rm -fsv"
    docker_remove_volumes="docker compose down -v"
    docker_version=$(docker compose version | head -n 1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    # --wait option has been introduced in 2.1.1+
    if [ "$(compare_versions "$docker_version" "2.1.0")" = "gt" ]; then
      docker="docker compose up --wait"
      need_wait_for_sequin=false
    else
      docker="docker compose up -d"
    fi
  fi
  set -e
}

choose_sequin_version() {
  if [ -z "${sequin_version:-}" ]; then
    # Default to latest
    sequin_version="latest"
  fi
}

# Create the start script (start.sh)
create_start_file() {
  cat > start.sh <<-'EOM'
#!/bin/sh
# Start script for Sequin start-local
# More information: https://github.com/sequinstream/sequin
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
. ./.env

EOM

  if [ "$need_wait_for_sequin" = true ]; then
    cat >> start.sh <<-'EOM'
wait_for_sequin() {
  local timeout="${1:-60}"
  echo "- Waiting for Sequin to be ready"
  echo
  local start_time="$(date +%s)"
  until curl -s http://localhost:7376/health | grep -q '"ok":true'; do
    elapsed_time="$(($(date +%s) - start_time))"
    if [ "$elapsed_time" -ge "$timeout" ]; then
      echo "Error: Sequin timeout of ${timeout} sec"
      exit 1
    fi
    sleep 2
  done
}

EOM
  fi

  cat >> start.sh <<- EOM
$docker
EOM

  if [ "$need_wait_for_sequin" = true ]; then
    cat >> start.sh <<-'EOM'
wait_for_sequin 120
EOM
  fi
  chmod +x start.sh
}

# Create the stop script (stop.sh)
create_stop_file() {
  cat > stop.sh <<-'EOM'
#!/bin/sh
# Stop script for Sequin start-local
# More information: https://github.com/sequinstream/sequin
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
EOM

  cat >> stop.sh <<- EOM
$docker_stop
EOM
  chmod +x stop.sh
}

# Create the uninstall script (uninstall.sh)
create_uninstall_file() {
  cat > uninstall.sh <<-'EOM'
#!/bin/sh
# Uninstall script for Sequin start-local
# More information: https://github.com/sequinstream/sequin
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ask_confirmation() {
    echo "Do you want to continue? (yes/no)"
    read -r answer
    case "$answer" in
        yes|y|Y|Yes|YES)
            return 0  # true
            ;;
        no|n|N|No|NO)
            return 1  # false
            ;;
        *)
            echo "Please answer yes or no."
            ask_confirmation  # Ask again if the input is invalid
            ;;
    esac
}

cd "${SCRIPT_DIR}"
if [ ! -e "docker-compose.yml" ]; then
  echo "Error: I cannot find the docker-compose.yml file"
  echo "I cannot uninstall Sequin start-local."
fi
if [ ! -e ".env" ]; then
  echo "Error: I cannot find the .env file"
  echo "I cannot uninstall Sequin start-local."
fi
echo "This script will uninstall Sequin start-local."
echo "All data will be deleted and cannot be recovered."
if ask_confirmation; then
EOM

  cat >> uninstall.sh <<- EOM
  $docker_clean
  $docker_remove_volumes
  rm docker-compose.yml .env uninstall.sh start.sh stop.sh
  echo "Sequin start-local successfully removed"
fi
EOM
  chmod +x uninstall.sh
}

create_env_file() {
  # Create the .env file
  cat > .env <<- EOM
SEQUIN_VERSION=$sequin_version
SEQUIN_CONTAINER_NAME=$sequin_container_name
PG_CONTAINER_NAME=$postgres_container_name
PG_DATABASE=sequin
PG_PLAYGROUND_DATABASE=sequin_playground
PG_USERNAME=postgres
PG_PASSWORD=postgres
PG_PORT=5432
REDIS_CONTAINER_NAME=$redis_container_name
REDIS_PORT=6379
EOM

  if [ -z "${minimal:-}" ]; then
    cat >> .env <<- EOM
PROMETHEUS_CONTAINER_NAME=$prometheus_container_name
GRAFANA_CONTAINER_NAME=$grafana_container_name
EOM
  fi
}

# Create the docker-compose-yml file
create_docker_compose_file() {
  cat > docker-compose.yml <<-'EOM'
name: sequin-local

services:
  sequin:
    image: sequin/sequin:${SEQUIN_VERSION}
    container_name: ${SEQUIN_CONTAINER_NAME}
    pull_policy: always
    ports:
      - "127.0.0.1:7376:7376"
    environment:
      - PG_HOSTNAME=${PG_CONTAINER_NAME}
      - PG_DATABASE=${PG_DATABASE}
      - PG_PORT=${PG_PORT}
      - PG_USERNAME=${PG_USERNAME}
      - PG_PASSWORD=${PG_PASSWORD}
      - PG_POOL_SIZE=20
      - SECRET_KEY_BASE=wDPLYus0pvD6qJhKJICO4dauYPXfO/Yl782Zjtpew5qRBDp7CZvbWtQmY0eB13If
      - VAULT_KEY=2Sig69bIpuSm2kv0VQfDekET2qy8qUZGI8v3/h3ASiY=
      - REDIS_URL=redis://${REDIS_CONTAINER_NAME}:${REDIS_PORT}
      - CONFIG_FILE_PATH=/config/playground.yml
    volumes:
      - ./playground.yml:/config/playground.yml
    depends_on:
      ${REDIS_CONTAINER_NAME}:
        condition: service_started
      ${PG_CONTAINER_NAME}:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:7376/health | grep -q '\"ok\":true'"]
      interval: 10s
      timeout: 2s
      retries: 5
      start_period: 5s
      start_interval: 1s

  postgres:
    image: postgres:16
    container_name: ${PG_CONTAINER_NAME}
    ports:
      - "127.0.0.1:7377:5432"
    environment:
      - POSTGRES_DB=${PG_DATABASE}
      - POSTGRES_USER=${PG_USERNAME}
      - POSTGRES_PASSWORD=${PG_PASSWORD}
    command: ["postgres", "-c", "wal_level=logical"]
    volumes:
      - sequin_postgres_data:/var/lib/postgresql/data
EOM

  if [ -z "${noplayground:-}" ]; then
    cat >> docker-compose.yml <<-'EOM'
      # Creates a sample database for the playground
      - ./postgres-init:/docker-entrypoint-initdb.d
EOM
  fi

  cat >> docker-compose.yml <<-'EOM'
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PG_USERNAME} -d ${PG_DATABASE}"]
      interval: 10s
      timeout: 2s
      retries: 5
      start_period: 5s
      start_interval: 1s

  redis:
    image: redis:7
    container_name: ${REDIS_CONTAINER_NAME}
    ports:
      - "127.0.0.1:7378:6379"
    command: ["redis-server", "--port", "6379"]
    volumes:
      - sequin_redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 2s
      retries: 5
      start_period: 2s
      start_interval: 1s
EOM

  if [ -z "${minimal:-}" ]; then
    cat >> docker-compose.yml <<-'EOM'

  prometheus:
    image: prom/prometheus
    container_name: ${PROMETHEUS_CONTAINER_NAME}
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "127.0.0.1:9090:9090"

  grafana:
    image: grafana/grafana
    container_name: ${GRAFANA_CONTAINER_NAME}
    ports:
      - "127.0.0.1:3000:3000"
    depends_on:
      - prometheus
    volumes:
      - sequin_grafana_data:/var/lib/grafana
      - ./grafana_datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml
      - ./grafana_dashboard.yml:/etc/grafana/provisioning/dashboards/dashboard.yml
      - ./dashboard.json:/etc/grafana/dashboards/dashboards/sequin.json
EOM
  fi

  cat >> docker-compose.yml <<-'EOM'

volumes:
  sequin_postgres_data:
  sequin_redis_data:
EOM

  if [ -z "${minimal:-}" ]; then
    cat >> docker-compose.yml <<-'EOM'
  sequin_grafana_data:
EOM
  fi
}

create_postgres_init() {
  if [ -z "${noplayground:-}" ]; then
    mkdir -p postgres-init
    cat > postgres-init/01-init-playground.sql <<-'EOM'
-- Create the Sequin playground database
CREATE DATABASE sequin_playground;

-- Connect to the playground database
\c sequin_playground;

-- Create products table
CREATE TABLE public.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Insert sample data
INSERT INTO public.products (name, description, price, stock) VALUES
('Avocados (3 pack)', 'Fresh organic avocados', 5.99, 48),
('Flank Steak (1 lb)', 'Grass-fed beef', 8.99, 24),
('Salmon Fillet (12 oz)', 'Wild-caught Alaskan salmon', 14.99, 12),
('Baby Spinach (16 oz)', 'Organic pre-washed spinach', 4.99, 30),
('Sourdough Bread', 'Freshly baked artisanal bread', 6.99, 15),
('Blueberries (6 oz)', 'Organic fresh blueberries', 3.99, 40);
EOM
  fi
}

create_prometheus_config() {
  if [ -z "${minimal:-}" ]; then
    cat > prometheus.yml <<-'EOM'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'sequin'
    metrics_path: /metrics
    static_configs:
      - targets: ['sequin:7376']
EOM
  fi
}

create_grafana_configs() {
  if [ -z "${minimal:-}" ]; then
    # Create Grafana datasource config
    cat > grafana_datasource.yml <<-'EOM'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOM

    # Create Grafana dashboard provisioning config
    cat > grafana_dashboard.yml <<-'EOM'
apiVersion: 1

providers:
  - name: 'Sequin'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards/dashboards
EOM

    # Create a simple dashboard for Sequin
    cat > dashboard.json <<-'EOM'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "PBFA97CFB590B2093"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 0.5,
            "gradientMode": "none",
            "hideFrom": {
              "legend": false,
              "tooltip": false,
              "viz": false
            },
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        },
        "tooltip": {
          "mode": "single",
          "sort": "none"
        }
      },
      "title": "Sequin Metrics",
      "type": "timeseries"
    }
  ],
  "refresh": "",
  "schemaVersion": 38,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Sequin Dashboard",
  "uid": "sequin",
  "version": 1,
  "weekStart": ""
}
EOM
  fi
}

create_playground_config() {
  # Create a sample playground configuration file
  cat > playground.yml <<-'EOM'
default_database_id: sequin_playground
databases:
  - id: sequin_playground
    name: Sequin Playground
    connection_details:
      hostname: postgres
      port: 5432
      database: sequin_playground
      username: postgres
      password: postgres
EOM
}

print_steps() {
  if [ -z "${minimal:-}" ]; then
    echo "⌛️ Setting up Sequin and all supporting services v${sequin_version}..."
  else
    echo "⌛️ Setting up Sequin core services v${sequin_version}..."
  fi
  echo
  echo "- Created the ${folder} folder containing the files:"
  echo "  - .env, with settings"
  echo "  - docker-compose.yml, for Docker services"
  echo "  - start/stop/uninstall commands"
  
  if [ -z "${noplayground:-}" ]; then
    echo "  - playground database setup"
  fi
  
  if [ -z "${minimal:-}" ]; then
    echo "  - prometheus and grafana configurations"
  fi
}

running_docker_compose() {
  # Execute docker compose
  echo "- Running ${docker}"
  echo
  set +e
  if ! $docker; then
    error_msg="Error: ${docker} command failed!"
    echo "$error_msg"
    if [ -z "${minimal:-}" ]; then
      generate_error_log "${error_msg}" "${sequin_container_name} ${postgres_container_name} ${redis_container_name} ${prometheus_container_name} ${grafana_container_name}"
    else
      generate_error_log "${error_msg}" "${sequin_container_name} ${postgres_container_name} ${redis_container_name}"
    fi
    cleanup
    exit 1
  fi
  set -e
}

sequin_health_check() {
  if [ "$need_wait_for_sequin" = true ]; then
    wait_for_sequin 120
  fi
}

success() {
  echo
  if [ -z "${minimal:-}" ]; then
    echo "🎉 Congrats, Sequin and all supporting services are installed and running in Docker!"
  else
    echo "🎉 Congrats, Sequin is installed and running in Docker!"
  fi
  echo
  echo "🌐 Open your browser at http://localhost:7376"
  echo
  echo "   Default login credentials:"
  echo "   Email: admin@sequinstream.com"
  echo "   Password: sequinpassword!"
  echo
  echo "📊 Postgres database is available at localhost:7377"
  echo "   Username: postgres"
  echo "   Password: postgres"

  if [ -z "${noplayground:-}" ]; then
    echo
    echo "🏝️  A playground database has been created with sample data"
  fi
  
  if [ -z "${minimal:-}" ]; then
    echo
    echo "📈 Monitoring:"
    echo "   - Prometheus: http://localhost:9090"
    echo "   - Grafana: http://localhost:3000 (admin/admin)"
  fi
  
  echo
  echo "Learn more at https://sequinstream.com/docs"
  echo
}

check_installation_folder() {
  # Check if $installation_folder exists
  folder=$installation_folder
  if [ -d "$folder" ]; then
    if [ -n "$(ls -A "$folder")" ]; then
      echo "It seems you have already a start-local installation in '${folder}'."
      if [ -f "$folder/uninstall.sh" ]; then
        echo "I cannot proceed unless you uninstall it, using the following command:"
        echo "cd $folder && ./uninstall.sh"
      else
        echo "I did not find the uninstall.sh file, you need to proceed manually."
        if [ -f "$folder/docker-compose.yml" ] && [ -f "$folder/.env" ]; then
          echo "Execute the following commands:"
          echo "cd $folder"
          echo "$docker_clean"
          echo "$docker_remove_volumes"
          echo "cd .."
          echo "rm -rf $folder"
        fi
      fi
      exit 1
    fi
  fi
}

check_docker_services() {
  # Check for docker containers running
  check_container_running "$sequin_container_name"
  check_container_running "$postgres_container_name"
  check_container_running "$redis_container_name"
  if [ -z "${minimal:-}" ]; then
    check_container_running "$prometheus_container_name"
    check_container_running "$grafana_container_name"
  fi
}

create_installation_folder() {
  # If $folder already exists, it is empty, see above
  if [ ! -d "$folder" ]; then 
    mkdir $folder
  fi
  cd $folder
  folder_to_clean=$folder
}

main() {
  parse_args "$@"
  startup
  check_requirements
  check_installation_folder
  check_docker_services
  create_installation_folder
  choose_sequin_version
  create_start_file
  create_stop_file
  create_uninstall_file
  create_env_file
  create_docker_compose_file
  create_postgres_init
  create_prometheus_config
  create_grafana_configs
  create_playground_config
  print_steps
  running_docker_compose
  sequin_health_check
  success
}

ctrl_c() { 
  cleanup
  exit 1
}

# Trap ctrl-c
trap ctrl_c INT

# Execute the script
main "$@"