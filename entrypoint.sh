#!/bin/sh

# Forward logs
ln -sf /dev/stdout /var/log/stdout.log
ln -sf /dev/stderr /var/log/stderr.log

# Check environment variable
if [[ -z "$SKLAND_TOKEN" ]]; then
  echo 'Environment variable "SKLAND_TOKEN" not found' >&2
  exit 1
fi

# Start crond
crond -f
