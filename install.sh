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
        SCRIPT_ROOT=/data/mta/Script/Dumps
        ;;
    secondary)
        SCRIPT_ROOT=/data/mta4/Script/Dumps
        ;;
    *)
        SCRIPT_ROOT="$1"
        ;;
esac

# Expand relative paths to absolute paths
SCRIPT_ROOT="$(realpath -m "${SCRIPT_ROOT}")"
mkdir -p "${SCRIPT_ROOT}"

rsync \
    -av \
    --delete \
    --times \
    --exclude-from="${SOURCE_DIR}/deploy-exclude.txt" \
    "${SOURCE_DIR}/" \
    "${SCRIPT_ROOT}/"

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