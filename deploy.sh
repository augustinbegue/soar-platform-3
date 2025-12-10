#!/bin/bash

# Check for AWS Credentials
if [ -z "$AWS_PROFILE" ]; then
  echo "AWS credentials are not set. Please set AWS_PROFILE."
  exit 1
fi

cd terraform
terraform apply -var-file=config/soutenance.tfvars -target=module.core -auto-approve
terraform apply -var-file=config/soutenance.tfvars -target=module.core -target=module.aurora -auto-approve
terraform apply -var-file=config/soutenance.tfvars -auto-approve

URL=$(terraform output -raw alb_dns_name)
FRONTEND_URL=$(terraform output -raw frontend_url)

cd ..

while true; do
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "http://$URL/health")
    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "Backend is healthy."
        break
    else
        echo "Waiting for backend to be healthy..."
        sleep 10
    fi
done

bash create-users.sh "http://$URL"

sed -e "s|\${FRONTEND_URL}|http://$URL|g" \
    -e "s|\${ALB_DNS_NAME}|$URL|g" \
    load-testing/p3-targets.txt > load-testing/p3-targets.final.txt

echo "Deployment completed."

echo BACKEND_URL: "http://$URL"
echo FRONTEND_URL: "http://$FRONTEND_URL"

echo "Load testing targets:"
cat load-testing/p3-targets.final.txt
