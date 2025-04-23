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

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    sh "start-local.sh" -noplayground
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function tear_down_after_script() {
    yes | "${DEFAULT_DIR}/uninstall.sh"
    rm -rf "${DEFAULT_DIR}"
}

function test_sequin_is_running() {  
    result=$(check_sequin_health "http://localhost:7376/health")
    assert_equals "ok" "$result"
}

function test_sequin_web_is_accessible() {  
    result=$(get_http_response_code "http://localhost:7376")
    assert_equals "200" "$result"
}

function test_postgres_is_running() {
    result=$(check_postgres_connection "localhost" "7377" "postgres" "postgres" "sequin")
    assert_equals "connected" "$result"
}

function test_playground_database_does_not_exist() {
    result=$(PGPASSWORD="postgres" psql -h localhost -p 7377 -U postgres -l | grep -c "sequin_playground")
    assert_equals "0" "$result"
}

function test_redis_is_running() {
    result=$(redis-cli -h localhost -p 7378 ping)
    assert_equals "PONG" "$result"
}

function test_prometheus_is_running() {
    result=$(get_http_response_code "http://localhost:9090")
    assert_equals "200" "$result"
}

function test_grafana_is_running() {
    result=$(get_http_response_code "http://localhost:3000")
    assert_equals "200" "$result"
} 