#!/bin/bash

# Copyright 2025 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

APP=${app}
ENV=${env}
AWS_REGION=${aws_region}
SPLUNK_VERSION=${splunk_version}
SPLUNK_BUILD=${splunk_build}
SPLUNK_FILENAME="splunk-$SPLUNK_VERSION-$SPLUNK_BUILD-Linux-x86_64.tgz"
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/$SPLUNK_VERSION/linux/$SPLUNK_FILENAME"

# Enable debugging and logging
set -x
set -e

# Create log directory with proper permissions
mkdir -p /var/log
touch /var/log/user-data.log
chmod 666 /var/log/user-data.log

# Install necessary packages
yum update -y
yum install -y wget
yum install -y jq

# Download and install Splunk
cd /opt
wget -O "$SPLUNK_FILENAME" "$SPLUNK_URL"
tar xvzf "$SPLUNK_FILENAME"
cd splunk/bin

# Retrieve credentials from Secrets Manager
max_attempts=$((5 * 60 / 30)) # 5 minutes with 30-second intervals = 10 attempts
attempt=1
retry_interval=30

# Retry loop
while true; do
    echo "Attempt $attempt to retrieve Splunk credentials..."
    
    SPLUNK_CREDS=$(aws secretsmanager get-secret-value \
        --region "$AWS_REGION" \
        --secret-id "$APP-$ENV-splunk-credentials" \
        --query 'SecretString' \
        --output text) && break # Break the loop if successful
    
    exit_code=$?
    
    if [ $attempt -ge $max_attempts ]; then
        echo "Failed to retrieve Splunk credentials after $max_attempts attempts"
        exit 1
    fi
    
    echo "Attempt $attempt failed. Retrying in $retry_interval seconds..."
    sleep $retry_interval
    ((attempt++))
done

# Parse the JSON response
SPLUNK_PASSWORD=$(echo $SPLUNK_CREDS | jq -r '.password')
SPLUNK_USERNAME=$(echo $SPLUNK_CREDS | jq -r '.username')

# Create admin user and start Splunk
./splunk start --accept-license --answer-yes --no-prompt --seed-passwd "$SPLUNK_PASSWORD"

# Enable JDBC connection
./splunk enable listen 8089 -auth "$SPLUNK_USERNAME:$SPLUNK_PASSWORD"

# Configure Splunk to start on boot
./splunk enable boot-start

# Additional Splunk configurations for JDBC
cat >> /opt/splunk/etc/system/local/server.conf <<EOL
[httpServer]
acceptFrom = *
allowSslCompression = true
enableSplunkdSSL = true
[general]
allowRemoteLogin = always
EOL

# Restart Splunk to apply changes
./splunk restart
