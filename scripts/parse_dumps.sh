#!/usr/bin/env bash

#
#--- Configure the MTA parsing of GOT Dumps files, for use in Dumps_mon and OTG analysis
#

#: Fail if any command fails, if any variable is unset, and if any command in a pipeline fails
set -euo pipefail
#: Determine the software root directory for the Dumps processing scripts
if [[ -z "${DUMPS_PROCESS_ROOT:-}" ]]; then
    #: If the DUMPS_PROCESS_ROOT environment variable is not set, then set it to the parent directory of the running script's directory.
    #: Assume the script resides in:
    #:   <DUMPS_PROCESS_ROOT>/scripts/
    #: Derive DUMPS_PROCESS_ROOT from the parent directory.
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    cd "${SCRIPT_DIR}"
    export DUMPS_PROCESS_ROOT="$(dirname "$(pwd)")"
fi
#: DUMPS_PROCESS_ROOT is set. Execute in the scripts directory of the Dumps processing root.
cd "${DUMPS_PROCESS_ROOT}/scripts"

#: Source the environment variables from the .env file if it exists
ENV_FILE="${DUMPS_PROCESS_ROOT}/instance/.env"

if [[ -f "${ENV_FILE}" ]]; then
    source "${ENV_FILE}"
fi

python parse_dump_files.py