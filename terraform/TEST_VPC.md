# 🧪 Guide de Test - Infrastructure VPC

Ce guide vous permet de tester progressivement votre infrastructure réseau VPC.

---

## ✅ Étape 1 : Validation de la syntaxe

**But** : Vérifier que le code Terraform est correct

```powershell
cd terraform
terraform validate
```

**Résultat attendu** :
```
Success! The configuration is valid.
```

---

## 📋 Étape 2 : Plan (Dry-Run)

**But** : Voir ce qui sera créé SANS rien déployer réellement

### 2.1 Configurer les credentials AWS

```powershell
# Option 1 : Variables d'environnement (temporaire pour cette session)
$env:AWS_ACCESS_KEY_ID="votre-access-key"
$env:AWS_SECRET_ACCESS_KEY="votre-secret-key"
$env:AWS_DEFAULT_REGION="eu-west-1"

# Option 2 : AWS CLI configure (permanent)
aws configure
# Entrez vos credentials quand demandé
```

### 2.2 Lancer le plan

```powershell
# Plan avec 3 AZ (production)
terraform plan -var-file="config/dev.tfvars"

# Ou créer un fichier pour 1 AZ seulement (économie)
# Voir section "Configuration Single AZ" plus bas
```
c
**Résultat attendu** :
```
Plan: 17 to add, 0 to change, 0 to destroy.
```

**Ressources qui seront créées** :
- 1 VPC
- 3 Public Subnets
- 3 Private Subnets
- 1 Internet Gateway
- 3 Elastic IPs
- 3 NAT Gateways
- 4 Route Tables (1 public + 3 private)
- + associations

---

## 🚀 Étape 3 : Déploiement réel

**⚠️ ATTENTION** : Cette commande va créer des ressources AWS réelles et peut générer des coûts !

```powershell
terraform apply -var-file="config/dev.tfvars"
```

Terraform va :
1. Afficher le plan
2. Demander confirmation : tapez **`yes`**
3. Créer les ressources (~2-3 minutes)

**Résultat attendu** :
```
Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

vpc_id = "vpc-0a1b2c3d4e5f6g7h8"
public_subnet_ids = [
  "subnet-xxx",
  "subnet-yyy",
  "subnet-zzz",
]
private_subnet_ids = [
  "subnet-aaa",
  "subnet-bbb",
  "subnet-ccc",
]
```

---

## 📊 Étape 4 : Vérifier les outputs

```powershell
# Voir tous les outputs
terraform output

# Output spécifique
terraform output vpc_id
terraform output public_subnet_ids
terraform output private_subnet_ids

# Format JSON
terraform output -json
```

**Sauvegardez ces IDs** pour les tests suivants !

---

## 🔍 Étape 5 : Vérifier dans AWS Console

### Via l'interface web :

1. **VPC Dashboard** : https://console.aws.amazon.com/vpc/
2. Sélectionnez la région : **eu-west-1** (Paris)
3. Vérifiez :
   - **Your VPCs** : Devrait montrer `soar-platform-dev-vpc`
   - **Subnets** : 6 subnets (3 public + 3 private)
   - **Internet Gateways** : 1 IGW attaché
   - **NAT Gateways** : 3 NAT en état "Available"
   - **Route Tables** : 4 route tables
   - **Elastic IPs** : 3 EIPs allouées

---

## 🖥️ Étape 6 : Vérifier avec AWS CLI

### 6.1 VPC

```powershell
# Récupérer le VPC ID
$VPC_ID = terraform output -raw vpc_id

# Détails du VPC
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region eu-west-1
```

**Vérifications** :
- `CidrBlock` = `10.20.0.0/16`
- `EnableDnsHostnames` = `true`
- `EnableDnsSupport` = `true`
- Tags : `Name=soar-platform-dev-vpc`

### 6.2 Subnets

```powershell
# Tous les subnets du VPC
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "Subnets[].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Type:Tags[?Key=='Type'].Value|[0]}" `
  --output table
```

**Attendu** :
```
-----------------------------------------------------------------
|                       DescribeSubnets                         |
+--------+---------------+------------------+-------------------+
|   AZ   |     CIDR      |       ID        |      Type         |
+--------+---------------+------------------+-------------------+
| eu-west-1a | 10.20.0.0/20   | subnet-xxx   | public           |
| eu-west-1b | 10.20.16.0/20  | subnet-yyy   | public           |
| eu-west-1c | 10.20.32.0/20  | subnet-zzz   | public           |
| eu-west-1a | 10.20.64.0/20  | subnet-aaa   | private          |
| eu-west-1b | 10.20.80.0/20  | subnet-bbb   | private          |
| eu-west-1c | 10.20.96.0/20  | subnet-ccc   | private          |
+--------+---------------+------------------+-------------------+
```

### 6.3 Internet Gateway

```powershell
aws ec2 describe-internet-gateways `
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" `
  --region eu-west-1
```

**Vérifier** : État = `attached`

### 6.4 NAT Gateways

```powershell
aws ec2 describe-nat-gateways `
  --filter "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "NatGateways[].{ID:NatGatewayId,Subnet:SubnetId,State:State,PublicIP:NatGatewayAddresses[0].PublicIp}" `
  --output table
```

**Vérifier** : 
- 3 NAT Gateways
- État = `available`
- Chacun dans un subnet public différent
- Chacun a une IP publique (EIP)

### 6.5 Route Tables

```powershell
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "RouteTables[].{ID:RouteTableId,Name:Tags[?Key=='Name'].Value|[0],Routes:Routes[?GatewayId!='local'].{Dest:DestinationCidrBlock,Target:GatewayId||NatGatewayId}}" `
  --output json
```

**Vérifier** :
- Route table **public** : Route `0.0.0.0/0` → `igw-xxx`
- Route tables **private** (x3) : Route `0.0.0.0/0` → `nat-xxx`

---

## 🌐 Étape 7 : Test de connectivité réseau

### Option A : Test rapide avec AWS CloudShell (recommandé pour débutants)

1. Allez dans AWS Console
2. Cliquez sur l'icône CloudShell (en haut à droite)
3. Pas besoin de créer d'instances !

### Option B : Test complet avec EC2 (plus avancé)

#### 7.1 Lancer une instance dans Public Subnet

```powershell
# Récupérer l'ID du premier subnet public
$PUBLIC_SUBNET = (terraform output -json public_subnet_ids | ConvertFrom-Json)[0]

# Créer un security group temporaire
aws ec2 create-security-group `
  --group-name test-public `
  --description "Test public subnet" `
  --vpc-id $VPC_ID `
  --region eu-west-1

$SG_PUBLIC = (aws ec2 describe-security-groups `
  --filters "Name=group-name,Values=test-public" "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "SecurityGroups[0].GroupId" `
  --output text)

# Autoriser SSH (si vous avez une paire de clés)
aws ec2 authorize-security-group-ingress `
  --group-id $SG_PUBLIC `
  --protocol tcp `
  --port 22 `
  --cidr 0.0.0.0/0 `
  --region eu-west-1

# Lancer une instance (remplacez YOUR_KEY_NAME)
aws ec2 run-instances `
  --image-id ami-0c55b159cbfafe1f0 `
  --instance-type t2.micro `
  --subnet-id $PUBLIC_SUBNET `
  --security-group-ids $SG_PUBLIC `
  --key-name YOUR_KEY_NAME `
  --associate-public-ip-address `
  --region eu-west-1 `
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-public}]'
```

**Test** : Connectez-vous en SSH et vérifiez l'accès internet
```bash
ssh -i your-key.pem ec2-user@<public-ip>
ping -c 4 8.8.8.8
curl https://api.ipify.org  # Voir votre IP publique
```

#### 7.2 Lancer une instance dans Private Subnet

```powershell
# Récupérer l'ID du premier subnet privé
$PRIVATE_SUBNET = (terraform output -json private_subnet_ids | ConvertFrom-Json)[0]

# Créer security group
aws ec2 create-security-group `
  --group-name test-private `
  --description "Test private subnet" `
  --vpc-id $VPC_ID `
  --region eu-west-1

$SG_PRIVATE = (aws ec2 describe-security-groups `
  --filters "Name=group-name,Values=test-private" "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "SecurityGroups[0].GroupId" `
  --output text)

# Autoriser tout depuis le VPC (pour SSH via bastion)
aws ec2 authorize-security-group-ingress `
  --group-id $SG_PRIVATE `
  --protocol -1 `
  --source-group $SG_PUBLIC `
  --region eu-west-1

# Lancer l'instance
aws ec2 run-instances `
  --image-id ami-0c55b159cbfafe1f0 `
  --instance-type t2.micro `
  --subnet-id $PRIVATE_SUBNET `
  --security-group-ids $SG_PRIVATE `
  --key-name YOUR_KEY_NAME `
  --region eu-west-1 `
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-private}]'
```

**Test** : SSH via l'instance publique (bastion)
```bash
# Depuis l'instance publique
ssh ec2-user@<private-ip>
ping -c 4 8.8.8.8  # ✅ Devrait fonctionner (via NAT)
curl https://api.ipify.org  # Devrait montrer l'IP du NAT Gateway
```

---

## 🧹 Étape 8 : Nettoyage (IMPORTANT !)

### 8.1 Supprimer les instances de test (si créées)

```powershell
# Lister toutes les instances
aws ec2 describe-instances `
  --filters "Name=vpc-id,Values=$VPC_ID" `
  --region eu-west-1 `
  --query "Reservations[].Instances[].InstanceId" `
  --output text

# Terminer les instances
aws ec2 terminate-instances `
  --instance-ids i-xxxxx i-yyyyy `
  --region eu-west-1

# Attendre qu'elles soient terminées
aws ec2 wait instance-terminated `
  --instance-ids i-xxxxx i-yyyyy `
  --region eu-west-1
```

### 8.2 Détruire l'infrastructure Terraform

**⚠️ ATTENTION** : Cela supprime TOUT !

```powershell
terraform destroy -var-file="config/dev.tfvars"
```

Tapez **`yes`** pour confirmer.

**Attendu** :
```
Destroy complete! Resources: 17 destroyed.
```

### 8.3 Vérifier qu'il ne reste rien

```powershell
# VPCs (ne devrait montrer que le default VPC)
aws ec2 describe-vpcs --region eu-west-1

# NAT Gateways (ne devrait rien montrer)
aws ec2 describe-nat-gateways --region eu-west-1

# Elastic IPs non attachées (à libérer si présentes)
aws ec2 describe-addresses --region eu-west-1
```

---

## 📝 Configuration Single AZ (pour économiser)

Pour tester avec **1 seul AZ** et réduire les coûts (~$32/mois au lieu de ~$96/mois) :

### Créer `terraform/config/dev-single-az.tfvars`

```hcl
project     = "soar-platform"
environment = "dev"
aws_region  = "eu-west-1"

# Single AZ only
availability_zones = ["eu-west-1a"]

vpc_cidr = "10.20.0.0/16"

# Only AZ "a"
public_subnet_cidrs = {
  "a" = "10.20.0.0/20"
}

private_subnet_cidrs = {
  "a" = "10.20.64.0/20"
}

database_subnet_cidrs = {
  "a" = "10.20.160.0/21"
}
```

### Utiliser cette config

```powershell
terraform plan -var-file="config/dev-single-az.tfvars"
terraform apply -var-file="config/dev-single-az.tfvars"
```

**Ressources créées** : 7 au lieu de 17 (1 NAT au lieu de 3)

---

## ✅ Checklist de validation

Après déploiement, vérifiez :

- [ ] `terraform output vpc_id` retourne un ID
- [ ] `terraform output public_subnet_ids` retourne 3 IDs (ou 1 si single-AZ)
- [ ] `terraform output private_subnet_ids` retourne 3 IDs (ou 1 si single-AZ)
- [ ] AWS Console montre le VPC avec bon nom
- [ ] NAT Gateways sont en état "Available"
- [ ] Route tables publiques pointent vers IGW
- [ ] Route tables privées pointent vers NAT
- [ ] Instance dans public subnet peut accéder à internet directement
- [ ] Instance dans private subnet peut accéder à internet via NAT
- [ ] Aucune erreur dans `terraform plan` après apply

---

## 💰 Estimation des coûts

### Configuration 3 AZ (dev.tfvars)

| Ressource | Quantité | Coût/mois |
|-----------|----------|-----------|
| VPC | 1 | Gratuit |
| Subnets | 6 | Gratuit |
| Internet Gateway | 1 | Gratuit |
| Elastic IPs (attachées) | 3 | Gratuit |
| **NAT Gateways** | 3 | **~$96** |
| Data processing | Variable | ~$0.045/GB |
| **TOTAL** | | **~$96-110/mois** |

### Configuration 1 AZ (dev-single-az.tfvars)

| Ressource | Quantité | Coût/mois |
|-----------|----------|-----------|
| NAT Gateway | 1 | **~$32** |
| Data processing | Variable | ~$0.045/GB |
| **TOTAL** | | **~$32-40/mois** |

---

## 🆘 Troubleshooting

### Erreur : "No valid credential sources found"

```powershell
# Configurer AWS credentials
aws configure
# ou
$env:AWS_ACCESS_KEY_ID="xxx"
$env:AWS_SECRET_ACCESS_KEY="xxx"
```

### Erreur : "UnauthorizedOperation"

Votre utilisateur IAM n'a pas les permissions. Attachez la policy `AmazonEC2FullAccess` (pour dev/test).

### NAT Gateway en état "Failed"

- Vérifier que l'EIP est bien créée
- Vérifier que le subnet est bien public
- Attendre 5 minutes et vérifier à nouveau

### `terraform destroy` bloqué

```powershell
# Forcer la destruction
terraform destroy -var-file="config/dev.tfvars" -auto-approve

# Si toujours bloqué, supprimer manuellement dans AWS Console puis :
terraform state rm <resource>
```

---

## 📚 Ressources utiles

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI VPC Commands](https://docs.aws.amazon.com/cli/latest/reference/ec2/)

---

**Prêt à tester !** Commencez par les étapes 1-2, puis décidez si vous voulez déployer réellement (étape 3). 🚀
