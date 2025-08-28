#!/bin/bash
# Store the original runtime API endpoint before overriding
export LRAP_RUNTIME_API_ENDPOINT="${AWS_LAMBDA_RUNTIME_API}"
# Redirect Lambda runtime to our proxy
export AWS_LAMBDA_RUNTIME_API="127.0.0.1:9009"
exec "$@"