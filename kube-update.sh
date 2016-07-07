#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE}")

source "$KUBE_ROOT/openrc-default.sh"

echo ${KUBE_ROOT}

source "${KUBE_ROOT}/util.sh"

echo "... calling kube-up" >&2
update-heat-script


exit 0
