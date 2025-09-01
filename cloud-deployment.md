# Cloud Deployment Guides

## Amazon EKS

### Prerequisites

#### Per Linux/Mac (Bash)
```bash
# Install AWS CLI and EKS CLI
aws configure
aws eks update-kubeconfig --region us-east-1 --name hazelcast-cluster

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

#### Per Windows (PowerShell)
```powershell
# Install AWS CLI and EKS CLI
aws configure
aws eks update-kubeconfig --region us-east-1 --name hazelcast-cluster

# Install Helm
irm https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | iex
```

### Deploy PostgreSQL
```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL
helm install postgresql bitnami/postgresql \
  --set postgresqlPassword=yourpassword \
  --set postgresqlDatabase=hazelcastdb \
  --set persistence.enabled=true \
  --set persistence.size=10Gi
```

### Deploy Application

#### Per Linux/Mac (Bash)
```bash
# Create namespace
kubectl create namespace hazelcast-demo

# Create secret
kubectl create secret generic db-secret \
  --from-literal=host=postgresql.default.svc.cluster.local \
  --from-literal=dbname=hazelcastdb \
  --from-literal=username=postgres \
  --from-literal=password=yourpassword \
  -n hazelcast-demo

# Deploy application
kubectl apply -f deployment.yaml -n hazelcast-demo
```

#### Per Windows (PowerShell)
```powershell
# Create namespace
kubectl create namespace hazelcast-demo

# Create secret
kubectl create secret generic db-secret `
  --from-literal=host=postgresql.default.svc.cluster.local `
  --from-literal=dbname=hazelcastdb `
  --from-literal=username=postgres `
  --from-literal=password=yourpassword `
  -n hazelcast-demo

# Deploy application
kubectl apply -f deployment.yaml -n hazelcast-demo
```

### Setup Monitoring
### Monitoring

Questa sezione è stata rimossa: il repository non fornisce più script di installazione per sistemi di monitoraggio specifici.

## Google GKE

### Prerequisites
```bash
# Install gcloud CLI
# Authenticate and set project
gcloud auth login
gcloud config set project your-project-id
gcloud container clusters get-credentials hazelcast-cluster --region us-central1
```

### Deploy PostgreSQL
```bash
# Use Google Cloud SQL
gcloud sql instances create hazelcast-db \
  --database-version=POSTGRES_13 \
  --region=us-central1 \
  --cpu=1 \
  --memory=4GB

# Create database
gcloud sql databases create hazelcastdb --instance=hazelcast-db
```

### Deploy Application
```yaml
# Use Cloud SQL proxy
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hazelcast-demo
spec:
  template:
    spec:
      containers:
      - name: hazelcast-demo
        env:
        - name: DB_HOST
          value: "127.0.0.1"
        - name: DB_PORT
          value: "5432"
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.28.0
        command:
          - "/cloud_sql_proxy"
          - "-instances=your-project-id:us-central1:hazelcast-db=tcp:5432"
        securityContext:
          runAsNonRoot: true
```

## Microsoft AKS

### Prerequisites
```bash
# Install Azure CLI
az login
az aks get-credentials --resource-group your-rg --name hazelcast-cluster
```

### Deploy PostgreSQL
```bash
# Use Azure Database for PostgreSQL
az postgres server create \
  --resource-group your-rg \
  --name hazelcast-postgres \
  --location eastus \
  --admin-user postgres \
  --admin-password yourpassword \
  --sku-name B_Gen5_1 \
  --version 13

# Create database
az postgres db create \
  --resource-group your-rg \
  --server-name hazelcast-postgres \
  --name hazelcastdb
```

### Deploy Application
```bash
# Create secret from Azure Key Vault
az keyvault secret set \
  --vault-name your-keyvault \
  --name db-password \
  --value yourpassword

# Use secret in deployment
kubectl create secret generic db-secret \
  --from-literal=host=hazelcast-postgres.postgres.database.azure.com \
  --from-literal=dbname=hazelcastdb \
  --from-literal=username=postgres@hazelcast-postgres \
  --from-literal=password=yourpassword
```

## Generic Kubernetes

### Using Kustomize
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

patchesStrategicMerge:
  - patches/env-patch.yaml

images:
  - name: hazelcast-demo
    newTag: v1.0.0
```

### Using Helm Chart
```yaml
# Chart.yaml
apiVersion: v2
name: hazelcast-demo
description: Hazelcast Demo Application
type: application
version: 0.1.0
appVersion: "1.0.0"

# values.yaml
replicaCount: 3

image:
  repository: your-registry/hazelcast-demo
  tag: latest

database:
  host: postgresql.default.svc.cluster.local
  port: 5432
  name: hazelcastdb
  username: postgres
  password: yourpassword
```

## Multi-Cloud Considerations

### Database
- **AWS**: RDS PostgreSQL
- **GCP**: Cloud SQL PostgreSQL
- **Azure**: Azure Database for PostgreSQL
- **On-prem**: Self-hosted PostgreSQL

### Monitoring
- **AWS**: Uso di soluzioni monitoring gestite (es. Amazon Managed Services)
- **GCP**: Cloud Monitoring + Cloud Logging
- **Azure**: Azure Monitor + Azure Log Analytics
- **On-prem**: Soluzioni di monitoring self-hosted o gestite

### Storage
- **AWS**: EBS, EFS
- **GCP**: Persistent Disk, Filestore
- **Azure**: Azure Disk, Azure Files
- **On-prem**: NFS, Ceph

### Networking
- **AWS**: VPC, Security Groups, Load Balancer
- **GCP**: VPC, Firewall rules, Load Balancer
- **Azure**: VNet, NSG, Load Balancer
- **On-prem**: Calico, Cilium, MetalLB
