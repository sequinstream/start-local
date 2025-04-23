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
START_FILE="${DEFAULT_DIR}/start.sh"
STOP_FILE="${DEFAULT_DIR}/stop.sh"
UNINSTALL_FILE="${DEFAULT_DIR}/uninstall.sh"

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    sh "start-local.sh"
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function tear_down_after_script() {
    yes | "${DEFAULT_DIR}/uninstall.sh"
    rm -rf "${DEFAULT_DIR}"
}

function test_stop_and_start() {
    # Stop the services
    "${STOP_FILE}"
    sleep 5
    
    # Check that Sequin is not running
    result=$(check_docker_service_running "${SEQUIN_CONTAINER_NAME}")
    assert_equals 1 $?
    
    # Start the services again
    "${START_FILE}"
    sleep 15
    
    # Check that Sequin is running
    result=$(check_docker_service_running "${SEQUIN_CONTAINER_NAME}")
    assert_equals 0 $?
    
    # Check Sequin health endpoint
    result=$(check_sequin_health "http://localhost:7376/health")
    assert_equals "ok" "$result"
}