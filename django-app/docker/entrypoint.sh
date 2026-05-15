#!/bin/sh
set -e

python manage.py migrate --no-input
exec gunicorn config.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --worker-class sync \
    --timeout 60
