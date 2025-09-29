#!/bin/sh

set -e

aws secretsmanager get-secret-value \
    --secret-id ansible/vault_pass \
    --region us-east-1 \
    --query SecretString --output text

