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

CURRENT_DIR=$(pwd)
DEFAULT_DIR="${CURRENT_DIR}/sequin-start-local"
ENV_PATH="${DEFAULT_DIR}/.env"
DOCKER_COMPOSE_FILE="${DEFAULT_DIR}/docker-compose.yml"
START_FILE="${DEFAULT_DIR}/start.sh"
STOP_FILE="${DEFAULT_DIR}/stop.sh"
UNINSTALL_FILE="${DEFAULT_DIR}/uninstall.sh"
HOST_PORT=8080

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    # Start a web server with the current path
    php -S localhost:${HOST_PORT} -t . &
    PHP_PID=$!
    
    # Wait for the server to start
    sleep 1
    
    # Run the curl command to install
    curl -fsSL http://localhost:${HOST_PORT}/start-local.sh | sh
    
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function tear_down_after_script() {
    # Kill the PHP server
    if [ -n "${PHP_PID}" ]; then
        kill ${PHP_PID}
    fi
    
    # Uninstall
    if [ -d "${DEFAULT_DIR}" ]; then
        yes | "${DEFAULT_DIR}/uninstall.sh"
        rm -rf "${DEFAULT_DIR}"
    fi
}

function test_docker_compose_file_exists() {
    assert_file_exists "${DOCKER_COMPOSE_FILE}"
}

function test_env_file_exists() {
    assert_file_exists "${ENV_PATH}"
}

function test_start_file_exists() {
    assert_file_exists "${START_FILE}"
}

function test_stop_file_exists() {
    assert_file_exists "${STOP_FILE}"
}

function test_uninstall_file_exists() {
    assert_file_exists "${UNINSTALL_FILE}"
}

function test_sequin_is_running() {  
    result=$(check_sequin_health "http://localhost:7376/health")
    assert_equals "ok" "$result"
}

function test_sequin_web_is_accessible() {  
    result=$(get_http_response_code "http://localhost:7376")
    assert_equals "200" "$result"
}