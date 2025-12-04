#!/bin/bash

# Load Test Setup Script
# This script prepares the p3-targets.json file with actual Terraform outputs

set -e

echo "🚀 Setting up load test targets..."

# Get Terraform outputs
cd terraform

FRONTEND_URL=$(terraform output -raw frontend_url 2>/dev/null || echo "FRONTEND_URL_NOT_FOUND")
ALB_DNS_NAME=$(terraform output -raw alb_dns_name 2>/dev/null || echo "ALB_DNS_NAME_NOT_FOUND")

cd ..

# Check if outputs were found
if [ "$FRONTEND_URL" = "FRONTEND_URL_NOT_FOUND" ] || [ "$ALB_DNS_NAME" = "ALB_DNS_NAME_NOT_FOUND" ]; then
    echo "❌ Error: Could not retrieve Terraform outputs"
    echo "   Make sure you are in the project root and have deployed the infrastructure"
    exit 1
fi

echo "📍 Frontend URL: $FRONTEND_URL"
echo "📍 ALB DNS Name: $ALB_DNS_NAME"

# Create the actual targets file by replacing placeholders
sed -e "s|\${FRONTEND_URL}|$FRONTEND_URL|g" \
    -e "s|\${ALB_DNS_NAME}|$ALB_DNS_NAME|g" \
    load-testing/p3-targets.txt > load-testing/p3-targets.final.txt
    
echo "✅ Load test targets file created: p3-targets.final.txt"
echo ""
echo "🎯 Ready to run load test with:"
echo '   ssh hamilton.server "cd ~/load-testing && vegeta attack -targets=p3-targets.final.txt -format=http -rate=200/s -duration=600s | vegeta report"'
echo ""
echo "📊 Alternative commands:"
echo "   # Generate HTML report"
echo '   ssh hamilton.server "cd ~/load-testing && vegeta attack -targets=p3-targets.final.txt -format=http -rate=200/s -duration=600s | vegeta report -reporter=html > report.html"'
echo ""
echo "   # Stream live results"
echo '   ssh hamilton.server "cd ~/load-testing && vegeta attack -targets=p3-targets.final.txt -format=http -rate=200/s -duration=600s | vegeta dump"'
