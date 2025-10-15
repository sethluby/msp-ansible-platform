"""
Minimal AWX settings stub for local demos/tests.
This file is mounted by docker-compose. Values are safely
overridden by environment variables in compose.
"""
import os

SECRET_KEY = os.environ.get("AWX_SECRET_KEY", "changeme")
DEBUG = False
ALLOWED_HOSTS = ["*"]

# Database settings are provided via environment variables in docker-compose
# DATABASES = { ... }

