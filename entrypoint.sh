#!/bin/bash
set -e

if [ "$(id -u)" = "0" ]; then
  exec runuser -u appuser -- env HOME=/home/appuser "$@"
fi

exec "$@"
