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
VERSION="latest"

# include external scripts
source "${CURRENT_DIR}/tests/utility.sh"

function set_up_before_script() {
    sh "start-local.sh" -v "${VERSION}"
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
}

function tear_down_after_script() {
    yes | "${DEFAULT_DIR}/uninstall.sh"
    rm -rf "${DEFAULT_DIR}"
}

function test_env_file_contains_version() {
    grep -q "SEQUIN_VERSION=${VERSION}" "${ENV_PATH}"
    exit_code=$?
    assert_equals 0 $exit_code
}

function test_docker_compose_uses_version() {
    grep -q "image: sequin/sequin:\${SEQUIN_VERSION}" "${DOCKER_COMPOSE_FILE}"
    exit_code=$?
    assert_equals 0 $exit_code
}

function test_sequin_is_running() {  
    result=$(check_sequin_health "http://localhost:7376/health")
    assert_equals "ok" "$result"
}

