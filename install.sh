#!/usr/bin/env bash

#: ANSI terminal colors
RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

#: Bash protective measures
set -euo pipefail

#: Set and change to the source code directory
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set the version variables
source "$SOURCE_DIR/version.conf"
#: Build ISO 8601 timestamp
BUILD=$(date -u +"%Y%m%dT%H%M%SZ")

#: Define the primary and secondary locations. Alwasy consult what is actually running on MTA systems for determining primary and secondary installations.
PRIMARY_DIR="/data/mta/Script/Dumps"
SECONDARY_DIR="/data/mta4/Script/Dumps"

usage() {
    cat <<EOF
MTA Dumps Parsing Installer
Version: ${VERSION}
Usage:
    $0 <install_path>
    $0 {primary|secondary}

Arguments:
    primary     Install to primary directory /data/mta/Script/Dumps
    secondary   Install to secondary directory /data/mta4/Script/Dumps
    install_path
                Install to an arbitrary directory

Examples:
    $0 primary
    $0 secondary
    $0 \$HOME/Dumps

Options:
    -h, --help  Show this help message

EOF
}


#: If more than one argument, then run the usage function for the help page
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
    primary)
        SCRIPT_ROOT="${PRIMARY_DIR}"
        ;;
    secondary)
        SCRIPT_ROOT="${SECONDARY_DIR}"
        ;;
    *)
        SCRIPT_ROOT="$1"
        ;;
esac

# Expand relative paths to absolute paths
SCRIPT_ROOT="$(realpath -m "${SCRIPT_ROOT}")"
mkdir -p "${SCRIPT_ROOT}"

#: Run the source code rsync
rsync \
    -av \
    --delete \
    --times \
    --exclude-from="${SOURCE_DIR}/deploy-exclude.txt" \
    "${SOURCE_DIR}/" \
    "${SCRIPT_ROOT}/"

#: Determine if the processing state files are present, and if not, warn the installer and suggest copiable locations.
check_state_file() {
    local state_file="$1"
    local target="${SCRIPT_ROOT}/scripts/state/${state_file}"

    if [[ ! -f "$target" ]]; then
        #: Missing state file. Recommend copying.
        echo
        echo -e "${YELLOW}=================================================================${NC}"
        echo -e "${YELLOW}STATE FILE REQUIRED${NC}"
        echo -e "${YELLOW}=================================================================${NC}"
        echo
        echo "Missing state file:"
        echo "    ${target}"
        echo
        echo "State files keep track of which Dump/tracelog files have been processed by this software to avoid repetition."
        echo "Check primary and secondary locations of Dumps processing for file copies."
        echo "PRIMARY_DIR=${PRIMARY_DIR}"
        echo "SECONDARY_DIR=${SECONDARY_DIR}"
        echo "and copy to your installed location."
        echo
    fi
}

check_state_file "processed_dumps.json"
check_state_file "processed_tracelogs.json"

#: Create a template instance environment file if it does not exist
if [[ ! -f "${SCRIPT_ROOT}/instance/.env" ]]; then
    mkdir -p "${SCRIPT_ROOT}/instance"

    cat > "${SCRIPT_ROOT}/instance/.env" <<'EOF'
# Dumps instance configuration
export EMAIL_ENABLED=0
export MTA_MAIL='mtadude@cfa.harvard.edu'
export ACIS_MAIL='acisdude@cfa.harvard.edu'
EOF
    echo -e "${YELLOW}=================================================================${NC}"
    echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED${NC}"
    echo -e "${YELLOW}=================================================================${NC}"
    echo "Created template configuration:"
    echo "    ${SCRIPT_ROOT}/instance/.env"
    echo
    echo "This installation requires an instance-specific configuration file:"
    echo
    echo "    ${SCRIPT_ROOT}/instance/.env"
    echo
    echo "For production, go to the create template file and define:"
    echo
    echo "    export EMAIL_ENABLED=1"
    echo "    export MTA_MAIL='mtadude@cfa.harvard.edu'"
    echo "    export ACIS_MAIL='acisdude@cfa.harvard.edu'"
    echo
    echo "Otherwise, the template configuration will be used and avoid sending alerts to production email recipients."
    echo "The Dumps monitoring scripts will NOT run unless these"
    echo "environment variables are explicitly configured."
    echo
    echo -e "${RED}WARNING:${NC} Copying a production .env file into a test"
    echo "installation may cause alerts to be sent to production"
    echo "email recipients."
    echo
fi


echo "${VERSION}+${BUILD}" > "${SCRIPT_ROOT}/.version"

echo
echo -e "${GREEN}Installation complete.${NC}"
echo "Version: ${VERSION}+${BUILD}"
echo