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
UNINSTALL_FILE="${DEFAULT_DIR}/uninstall.sh"

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    sh "start-local.sh"
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function test_uninstall() {
    yes | "${UNINSTALL_FILE}"
    
    # Check that the installation folder has been removed
    if [ -d "${DEFAULT_DIR}" ]; then
        assert_fail "The installation folder ${DEFAULT_DIR} still exists"
    fi
    
    # Check that Sequin container is not running
    result=$(check_docker_service_running "${SEQUIN_CONTAINER_NAME}")
    assert_equals 1 $?
    
    # Check that Postgres container is not running
    result=$(check_docker_service_running "${PG_CONTAINER_NAME}")
    assert_equals 1 $?
    
    # Check that Redis container is not running
    result=$(check_docker_service_running "${REDIS_CONTAINER_NAME}")
    assert_equals 1 $?
    
    # Check that Prometheus container is not running (if it was started)
    if [ -n "${PROMETHEUS_CONTAINER_NAME:-}" ]; then
        result=$(check_docker_service_running "${PROMETHEUS_CONTAINER_NAME}")
        assert_equals 1 $?
    fi
    
    # Check that Grafana container is not running (if it was started)
    if [ -n "${GRAFANA_CONTAINER_NAME:-}" ]; then
        result=$(check_docker_service_running "${GRAFANA_CONTAINER_NAME}")
        assert_equals 1 $?
    fi
    
    # Check that Sequin is not accessible
    result=$(get_http_response_code "http://localhost:7376")
    assert_not_equals "200" "$result"
}

function tear_down_after_script() {
    # Cleanup if test fails
    if [ -d "${DEFAULT_DIR}" ]; then
        yes | "${UNINSTALL_FILE}" 2>/dev/null || true
        rm -rf "${DEFAULT_DIR}"
    fi
}