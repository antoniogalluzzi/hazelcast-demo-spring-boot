# OpenShift Local Development Guide

## 🚀 Quick Start

### 1. Setup Environment
```bash
# Install OpenShift Local
crc setup
crc start

# Login to cluster
oc login -u kubeadmin -p $(crc console --credentials | grep Password | awk '{print $2}') https://api.crc.testing:6443

# Create project
oc new-project hazelcast-demo-dev
```

### 2. Deploy Database
```bash
# One-command PostgreSQL deployment
oc new-app postgresql-ephemeral \
  --param DATABASE_SERVICE_NAME=postgresql \
  --param POSTGRESQL_DATABASE=hazelcastdb \
  --param POSTGRESQL_USER=hazelcast \
  --param POSTGRESQL_PASSWORD=hazelcast123 \
  --param POSTGRESQL_VERSION=13
```

### 3. Deploy Application
```bash
# Build and deploy in one go
oc new-build --name=hazelcast-demo --binary --image-stream=java:openjdk-21-ubi8:latest
oc start-build hazelcast-demo --from-dir=. --follow

oc new-app hazelcast-demo:latest \
  --name=hazelcast-demo \
  --env=DB_HOST=postgresql.hazelcast-demo-dev.svc.cluster.local \
  --env=DB_NAME=hazelcastdb \
  --env=DB_USERNAME=hazelcast \
  --env=DB_PASSWORD=hazelcast123

oc scale deployment hazelcast-demo --replicas=2
```

### 4. Test
```bash
# Get application URL
oc get routes

# Test API
curl http://hazelcast-demo-hazelcast-demo-dev.apps-crc.testing/user/1
```

## 📋 Detailed Setup

### System Requirements
- **RAM**: 16GB minimum (32GB recommended)
- **CPU**: 6 cores minimum (8+ recommended)
- **Storage**: 35GB free space
- **OS**: Windows 10/11 Pro, macOS 10.15+, RHEL/CentOS 8+, Ubuntu 18.04+

### Installation Steps

#### Windows
```powershell
# Download CRC from Red Hat console
# Run as Administrator
crc setup
crc start --cpus 6 --memory 16384

# Set environment variables
crc oc-env | Invoke-Expression
```

#### macOS
```bash
# Download and install CRC
crc setup
crc start --cpus 6 --memory 16384

# Add to PATH
eval $(crc oc-env)
```

#### Linux
```bash
# Download CRC
crc setup
crc start --cpus 6 --memory 16384

# Configure
eval $(crc oc-env)
```

## 🛠️ Development Workflow

### Local Development with Hot Reload
```bash
# Start local PostgreSQL
docker run -d --name postgres-dev -e POSTGRES_PASSWORD=dev123 -p 5432:5432 postgres:13

# Run Spring Boot with dev profile
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Test locally
curl http://localhost:8080/swagger-ui.html
```

### Deploy to OpenShift Local
```bash
# Build and push to local registry
oc new-build --name=hazelcast-demo --binary --image-stream=java:openjdk-21-ubi8:latest
oc start-build hazelcast-demo --from-dir=. --follow

# Deploy with dev configuration
oc apply -f deployment-dev.yaml
```

### CI/CD Pipeline
```yaml
# .github/workflows/openshift-local.yml
name: OpenShift Local CI/CD

on:
  push:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup OpenShift Local
      run: |
        curl -L https://github.com/code-ready/crc/releases/download/2.15.0/crc-linux-amd64.tar.xz | tar xJ
        sudo ./crc setup
        ./crc start --cpus 4 --memory 8192
    - name: Deploy and Test
      run: |
        oc login -u kubeadmin -p $(./crc console --credentials | grep Password | awk '{print $2}') https://api.crc.testing:6443
        # Deploy steps...
```

## 🔧 Configuration Files

### Development Deployment
```yaml
# deployment-dev.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hazelcast-demo-dev
  labels:
    app: hazelcast-demo
    environment: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hazelcast-demo
  template:
    metadata:
      labels:
        app: hazelcast-demo
        environment: dev
    spec:
      containers:
      - name: hazelcast-demo
        image: hazelcast-demo:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "dev"
        - name: DB_HOST
          value: "postgresql.hazelcast-demo-dev.svc.cluster.local"
        - name: DB_NAME
          value: "hazelcastdb"
        - name: DB_USERNAME
          value: "hazelcast"
        - name: DB_PASSWORD
          value: "hazelcast123"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: hazelcast-demo-service
spec:
  selector:
    app: hazelcast-demo
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: hazelcast-demo-route
spec:
  to:
    kind: Service
    name: hazelcast-demo-service
  port:
    targetPort: 8080
```

### Development ConfigMap
```yaml
# config-dev.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hazelcast-config-dev
data:
  hazelcast.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <hazelcast xmlns="http://www.hazelcast.com/schema/config"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://www.hazelcast.com/schema/config
               http://www.hazelcast.com/schema/config/hazelcast-config-5.1.xsd">
        <cluster-name>hazelcast-demo-dev</cluster-name>
        <network>
            <join>
                <kubernetes enabled="true">
                    <namespace>hazelcast-demo-dev</namespace>
                    <service-name>hazelcast-demo-service</service-name>
                </kubernetes>
            </join>
        </network>
        <map name="users">
            <time-to-live-seconds>300</time-to-live-seconds>
            <max-idle-seconds>120</max-idle-seconds>
        </map>
    </hazelcast>
```

## 🧪 Testing Strategies

### Unit Tests
```bash
# Run tests locally
./mvnw test

# With coverage
./mvnw test jacoco:report
```

### Integration Tests on OpenShift
```bash
# Deploy test environment
oc apply -f deployment-dev.yaml

# Run integration tests
./mvnw verify -Dspring.profiles.active=openshift

# Cleanup
oc delete -f deployment-dev.yaml
```

### Performance Testing
```bash
# Load test with hey
hey -n 1000 -c 10 http://hazelcast-demo-hazelcast-demo-dev.apps-crc.testing/user/1

# Monitor resources
oc top pods
oc top nodes
```

## 📊 Monitoring & Debugging

### Application Logs
```bash
# Follow application logs
oc logs -f deployment/hazelcast-demo

# Logs from specific pod
oc logs -f hazelcast-demo-12345-abcde

# Previous container logs
oc logs -f hazelcast-demo-12345-abcde --previous
```

### Hazelcast Cluster Status
```bash
# Check cluster members
oc exec -it hazelcast-demo-12345-abcde -- curl http://localhost:5701/hazelcast/health

# View Hazelcast management center (if enabled)
oc port-forward hazelcast-demo-12345-abcde 8080:8080
```

### Database Debugging
```bash
# Connect to PostgreSQL
oc rsh postgresql-1-abcde
psql -h localhost -U hazelcast hazelcastdb

# Check connections
SELECT * FROM pg_stat_activity;

# Monitor slow queries
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
```

## 🔄 Development Best Practices

### Code Changes
```bash
# Make changes locally
# Test with unit tests
./mvnw test

# Build locally
./mvnw clean package

# Deploy to OpenShift Local
oc start-build hazelcast-demo --from-dir=. --follow

# Test integration
curl http://hazelcast-demo-hazelcast-demo-dev.apps-crc.testing/actuator/health
```

### Database Migrations
```bash
# Create migration script
# src/main/resources/db/migration/V1__Initial_schema.sql

# Test migration locally
./mvnw flyway:migrate

# Deploy to OpenShift
oc start-build hazelcast-demo --from-dir=. --follow
```

### Environment Variables
```bash
# Set development environment
oc set env deployment/hazelcast-demo SPRING_PROFILES_ACTIVE=dev

# Update database config
oc set env deployment/hazelcast-demo DB_HOST=new-postgres-host

# Restart deployment
oc rollout restart deployment/hazelcast-demo
```

## 🚨 Common Issues & Solutions

### Issue: CRC won't start
```bash
# Check system resources
crc status

# Clean and restart
crc cleanup
crc setup
crc start --cpus 4 --memory 8192
```

### Issue: Build fails
```bash
# Check build logs
oc logs -f bc/hazelcast-demo

# Verify source code
oc describe bc/hazelcast-demo

# Rebuild
oc start-build hazelcast-demo --from-dir=. --follow
```

### Issue: Application crashes
```bash
# Check pod status
oc get pods
oc describe pod hazelcast-demo-12345-abcde

# View crash logs
oc logs hazelcast-demo-12345-abcde --previous

# Debug with shell
oc rsh hazelcast-demo-12345-abcde
```

### Issue: Database connection fails
```bash
# Verify database pod
oc get pods -l app=postgresql

# Check database logs
oc logs postgresql-1-abcde

# Test connection
oc rsh postgresql-1-abcde psql -h localhost -U hazelcast hazelcastdb -c "SELECT 1;"
```

## 📚 Additional Resources

- [OpenShift Local Documentation](https://console.redhat.com/openshift/create/local)
- [CRC Troubleshooting Guide](https://code-ready.github.io/crc/)
- [OpenShift Developer Guide](https://docs.openshift.com/container-platform/latest/applications/application_life_cycle_management/odc-creating-applications-using-developer-perspective.html)
- [Spring Boot on OpenShift](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html#deployment.cloud.openshift)
