#!/bin/bash
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

# Returns the HTTP status code from a call
# usage: get_http_response_code url [username] [password]
function get_http_response_code() {
    url=$1
    if [ -z "$url" ]; then
        echo "Error: you need to specify the URL for get the HTTP response"
        exit 1
    fi   
    username=$2
    password=$3

    if [ -z "$username" ] || [ -z "$password" ]; then
        result=$(curl -LI "$url" -o /dev/null -w '%{http_code}\n' -s)
    else
        result=$(curl -LI -u "$username":"$password" "$url" -o /dev/null -w '%{http_code}\n' -s)
    fi

    echo "$result"
}

# Check Sequin health endpoint
# usage: check_sequin_health url
function check_sequin_health() {
    url=$1
    if [ -z "$url" ]; then
        url="http://localhost:7376/health"
    fi

    result=$(curl -s "$url")
    if [[ "$result" == *"\"ok\":true"* ]]; then
        echo "ok"
    else
        echo "error"
    fi
}

# Login to Sequin using email and password
# usage: login_sequin url email password
function login_sequin() {
    url=$1
    if [ -z "$url" ]; then
        echo "Error: you need to specify the URL for login to Sequin"
        exit 1
    fi 
    email=$2
    password=$3
    if [ -z "$email" ] || [ -z "$password" ]; then
        echo "Error: you need to specify email and password to login to Sequin"
        exit 1
    fi

    result=$(curl -X POST \
        -H "Content-Type: application/json" \
        -d '{"email":"'"$email"'","password":"'"$password"'"}' \
        "${url}/api/auth/login" \
        -o /dev/null \
        -w '%{http_code}\n' -s)

    echo "$result"
}

# Check if PostgreSQL is accessible
# usage: check_postgres_connection host port user password database
function check_postgres_connection() {
    host=${1:-localhost}
    port=${2:-7377}
    user=${3:-postgres}
    password=${4:-postgres}
    database=${5:-sequin}

    # Using PGPASSWORD to avoid password prompt
    result=$(PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1" -t -q 2>/dev/null)
    
    if [ "$result" = " 1" ] || [ "$result" = "1" ]; then
        echo "connected"
    else
        echo "error"
    fi
}

# Tee the output in a file
function cap () { tee "${1}/capture.out"; }

# Return the previous output
function ret () { cat "${1}/capture.out"; }

# Check if a docker service is running
check_docker_service_running() {
  local container_name=$1
  local containers
  containers=$(docker ps --format '{{.Names}}')
  if echo "$containers" | grep -q "^${container_name}$"; then
    return 0 # true
  else
    return 1 # false
  fi
}