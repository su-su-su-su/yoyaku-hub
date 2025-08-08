#!/bin/bash

# Staging Environment Setup Script for Yoyaku Hub
# This script sets up the staging environment on the same VPS as production
# Run this script on your VPS after deploying the code

set -e

echo "=== Yoyaku Hub Staging Environment Setup ==="
echo ""

# Variables
STAGING_DIR="/var/www/yoyaku-hub-staging"
STAGING_DB="yoyaku_hub_staging"
NGINX_CONF="/etc/nginx/sites-available/staging-yoyaku-hub"
HTPASSWD_FILE="/etc/nginx/.htpasswd_staging"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "1. Checking prerequisites..."
if ! command_exists psql; then
    echo "Error: PostgreSQL is not installed"
    exit 1
fi

if ! command_exists nginx; then
    echo "Error: Nginx is not installed"
    exit 1
fi

echo "   Prerequisites OK"
echo ""

# Create staging directory
echo "2. Creating staging directory..."
if [ ! -d "$STAGING_DIR" ]; then
    sudo mkdir -p $STAGING_DIR
    sudo chown deploy:deploy $STAGING_DIR
    echo "   Created $STAGING_DIR"
else
    echo "   Directory $STAGING_DIR already exists"
fi
echo ""

# Create staging database
echo "3. Setting up staging database..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$STAGING_DB'" | grep -q 1 || \
    sudo -u postgres createdb $STAGING_DB
echo "   Database $STAGING_DB ready"
echo ""

# Setup Nginx configuration
echo "4. Setting up Nginx configuration..."
if [ ! -f "$NGINX_CONF" ]; then
    sudo cp config/nginx/staging-yoyaku-hub.conf $NGINX_CONF
    sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
    echo "   Nginx configuration installed"
else
    echo "   Nginx configuration already exists"
fi
echo ""

# Create Basic Auth credentials
echo "5. Setting up Basic Authentication..."
if [ ! -f "$HTPASSWD_FILE" ]; then
    echo "Enter username for staging environment:"
    read STAGING_USER
    sudo htpasswd -c $HTPASSWD_FILE $STAGING_USER
    echo "   Basic auth credentials created"
else
    echo "   Basic auth already configured"
fi
echo ""

# Create shared directories for Capistrano
echo "6. Creating shared directories..."
SHARED_DIRS=(
    "$STAGING_DIR/shared"
    "$STAGING_DIR/shared/config"
    "$STAGING_DIR/shared/config/credentials"
    "$STAGING_DIR/shared/log"
    "$STAGING_DIR/shared/tmp"
    "$STAGING_DIR/shared/tmp/pids"
    "$STAGING_DIR/shared/tmp/sockets"
    "$STAGING_DIR/shared/vendor"
    "$STAGING_DIR/shared/vendor/bundle"
    "$STAGING_DIR/shared/public"
    "$STAGING_DIR/shared/public/system"
    "$STAGING_DIR/shared/node_modules"
)

for dir in "${SHARED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p $dir
        echo "   Created $dir"
    fi
done

sudo chown -R deploy:deploy $STAGING_DIR
echo "   Shared directories ready"
echo ""

# Create .env.staging file
echo "7. Creating environment file..."
if [ ! -f "$STAGING_DIR/shared/.env.staging" ]; then
    cat > $STAGING_DIR/shared/.env.staging << EOL
# Staging Environment Variables
RAILS_ENV=staging
GOOGLE_CLIENT_ID='${GOOGLE_CLIENT_ID}'
GOOGLE_CLIENT_SECRET='${GOOGLE_CLIENT_SECRET}'
GMAIL_USERNAME='${GMAIL_USERNAME}'
GMAIL_PASSWORD='${GMAIL_PASSWORD}'
APP_DATABASE_USER='${APP_DATABASE_USER}'
YOYAKU_HUB_DATABASE_PASSWORD='${YOYAKU_HUB_DATABASE_PASSWORD}'
YOYAKU_HUB_DATABASE_HOST='localhost'
EOL
    chmod 600 $STAGING_DIR/shared/.env.staging
    echo "   Created .env.staging (Please update with actual values)"
else
    echo "   .env.staging already exists"
fi
echo ""

# Generate staging credentials key
echo "8. Setting up Rails credentials..."
if [ ! -f "$STAGING_DIR/shared/config/credentials/staging.key" ]; then
    echo "   Please create staging.key file:"
    echo "   Run: EDITOR=vim rails credentials:edit --environment staging"
    echo "   Then copy the key to: $STAGING_DIR/shared/config/credentials/staging.key"
else
    echo "   Staging credentials key exists"
fi
echo ""

# SSL Certificate setup reminder
echo "9. SSL Certificate Setup"
echo "   To set up SSL for staging.yoyakuhub.jp:"
echo "   sudo certbot --nginx -d staging.yoyakuhub.jp"
echo ""

# Test Nginx configuration
echo "10. Testing Nginx configuration..."
sudo nginx -t
echo ""

# Reload Nginx
echo "11. Reloading Nginx..."
sudo systemctl reload nginx
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Update $STAGING_DIR/shared/.env.staging with actual values"
echo "2. Create staging credentials key if not done"
echo "3. Set up SSL certificate with Let's Encrypt"
echo "4. Deploy with: cap staging deploy"
echo ""
echo "To deploy staging:"
echo "  cap staging deploy"
echo ""
echo "To access staging logs:"
echo "  tail -f $STAGING_DIR/shared/log/staging.log"
echo ""