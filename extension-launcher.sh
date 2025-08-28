#!/bin/bash
set -euo pipefail
OWN_FILENAME="$(basename $0)"
LAMBDA_EXTENSION_NAME="$OWN_FILENAME"
cd "/opt/${LAMBDA_EXTENSION_NAME}"
exec node index.mjs