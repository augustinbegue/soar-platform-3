cd terraform
terraform apply -var-file=soutenance.tfvars -target=module.core -auto-approve
terraform apply -var-file=soutenance.tfvars -target=module.core -target=module.aurora -auto-approve
terraform apply -var-file=soutenance.tfvars -auto-approve

URL=$(terraform output -raw alb_dns_name)

cd ..

create-users.sh "http://$URL"

sed -e "s|\${FRONTEND_URL}|$FRONTEND_URL|g" \
    -e "s|\${ALB_DNS_NAME}|$ALB_DNS_NAME|g" \
    load-testing/p3-targets.txt > load-testing/p3-targets.final.txt

cat load-testing/p3-targets.final.txt
