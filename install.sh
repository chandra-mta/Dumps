#!/usr/bin/env bash

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

echo "${VERSION}+${BUILD}" > "${SCRIPT_ROOT}/.version"

echo "Installation complete."
echo "Version: ${VERSION}+${BUILD}"