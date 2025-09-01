# 📚 Hazelcast Demo - Documentazione Completa

> **Guida Unificata** - Tutto quello che serve per sviluppare, testare e deployare il progetto

**👤 Autore**: Antonio Galluzzi  
**📧 Email**: antonio.galluzzi91@gmail.com  
**🐙 GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)  
**📅 Ultimo aggiornamento**: 1 Settembre 2025  
**📖 Versione**: 2.0.0

---

## 📖 Indice Generale

### 🚀 **[Quick Start](#quick-start)**
- [Panoramica Progetto](#panoramica-progetto)
- [Prerequisiti](#prerequisiti)
- [Sviluppo Locale (5 minuti)](#sviluppo-locale)

### 🏗️ **[Architettura](#architettura)**
- [Stack Tecnologico](#stack-tecnologico)
- [Componenti Sistema](#componenti-sistema)
- [Cache Distribuita](#cache-distribuita)

### ⚙️ **[Configurazione](#configurazione)**
- [Profili Ambiente](#profili-ambiente)
- [Database Setup](#database-setup)
- [Hazelcast Config](#hazelcast-config)

### 🚀 **[Deployment](#deployment)**
- [Docker Build](#docker-build)
- [OpenShift Local](#openshift-local)
- [Cloud Providers](#cloud-providers)

### 🧪 **[Testing](#testing)**
- [Test Locali](#test-locali)
- [API Testing](#api-testing)
- [Performance Testing](#performance-testing)

### 🔧 **[Troubleshooting](#troubleshooting)**
- [Problemi Comuni](#problemi-comuni)
- [Log Analysis](#log-analysis)
- [Debug Guide](#debug-guide)

### 📋 **[Riferimenti](#riferimenti)**
- [API Reference](#api-reference)
- [Changelog](#changelog)
- [Licenza](#licenza)

---

## 🚀 Quick Start

### Panoramica Progetto

Questo progetto dimostra l'integrazione di **Spring Boot** con **Hazelcast** per cache distribuita e **PostgreSQL** come database, deployabile su **OpenShift/Kubernetes**.

**🎯 Cosa fa il progetto:**
- Cache distribuita in-memory con Hazelcast
- API REST per gestione utenti
- Persistenza dati con PostgreSQL/H2
- Metriche e monitoring avanzato
- Deploy cloud-native

**⚡ Setup in 30 secondi:**
```bash
# Clone e avvio rapido
git clone https://github.com/antoniogalluzzi/hazelcast-demo-spring-boot.git
cd hazelcast-demo-spring-boot
./mvnw spring-boot:run

# Test API
curl http://localhost:8080/actuator/health
```

### Prerequisiti

| Strumento | Versione | Obbligatorio | Note |
|-----------|----------|--------------|------|
| **Java** | 17+ | ✅ | OpenJDK o Oracle |
| **Maven** | 3.8+ | ✅ | Wrapper incluso |
| **Docker** | 20+ | 🔧 | Per build container |
| **OpenShift Local** | 4.10+ | ☁️ | Per deploy locale |
| **curl** | Latest | 🧪 | Per testing API |

### Sviluppo Locale

#### 1. Avvio Rapido con H2
```bash
# Avvia con database in-memory
./mvnw clean spring-boot:run -Dspring-boot.run.profiles=dev

# L'app sarà disponibile su: http://localhost:8080
```

#### 2. Test Funzionamento
```bash
# Health check
curl http://localhost:8080/actuator/health

# Console H2 Database
open http://localhost:8080/h2-console
# JDBC URL: jdbc:h2:mem:testdb
# Username: sa
# Password: password

# Swagger API Documentation  
open http://localhost:8080/swagger-ui.html
```

#### 3. Test Cache Distribuita
```bash
# Crea utente (va in cache)
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Mario Rossi", "email": "mario@example.com"}'

# Recupera utente (dalla cache)
curl http://localhost:8080/user/1

# Verifica cache
curl http://localhost:8080/cache/stats
```

---

## 🏗️ Architettura

### Stack Tecnologico

```mermaid
graph TB
    A[Spring Boot 2.7.18] --> B[Hazelcast 5.1.7]
    A --> C[PostgreSQL 13]
    A --> D[Micrometer Metrics]
    B --> E[In-Memory Cache]
    C --> F[JPA/Hibernate]
    D --> G[Actuator Endpoints]
```

**🔧 Dipendenze Chiave:**
- **Spring Boot**: 2.7.18 (Framework principale)
- **Hazelcast**: 5.1.7 (Cache distribuita)
- **PostgreSQL**: 13+ (Database produzione)
- **H2**: 2.1+ (Database sviluppo)
- **Micrometer**: Metriche e monitoring

### Componenti Sistema

#### 🎯 Application Layer
- **HazelcastDemoApplication**: Main class
- **User Entity**: Modello dati JPA
- **UserController**: REST endpoints
- **CacheController**: Cache management

#### 💾 Data Layer  
- **PostgreSQL**: Persistenza produzione
- **H2**: Database in-memory per dev
- **Hazelcast**: Cache L2 distribuita

#### 📊 Monitoring Layer
- **Actuator**: Health, metrics, info
- **Micrometer**: Instrumentazione metriche
- **OpenAPI**: Documentazione automatica

### Cache Distribuita

#### Configurazione Hazelcast
```yaml
hazelcast:
  cluster-name: hazelcast-demo-cluster
  instance-name: hazelcast-demo-instance
  network:
    join:
      multicast:
        enabled: true  # Dev locale
      kubernetes:
        enabled: true  # Produzione
```

#### Cache Mapping
- **users**: Cache principale utenti (TTL: 10 min)
- **cache-stats**: Statistiche cache
- **cluster-info**: Informazioni cluster

---

## ⚙️ Configurazione

### Profili Ambiente

Il progetto supporta 4 profili principali:

#### 🔧 Development (`dev`)
```yaml
# application-dev.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driver-class-name: org.h2.Driver
  h2.console.enabled: true
  jpa.hibernate.ddl-auto: create-drop

hazelcast:
  network.join.multicast.enabled: true
```

#### 🧪 Staging (`staging`)  
```yaml
# application-staging.yml
spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/hazelcast_demo
    username: ${DB_USER:demo_user}
    password: ${DB_PASSWORD:demo_pass}

hazelcast:
  network.join.tcp-ip.enabled: true
  network.join.tcp-ip.members: staging-node-1,staging-node-2
```

#### 🚀 Production (`prod`)
```yaml
# application-prod.yml
spring:
  datasource:
    url: jdbc:postgresql://postgres:5432/hazelcast_demo
    username: ${DB_USER}
    password: ${DB_PASSWORD}
  jpa.hibernate.ddl-auto: validate

hazelcast:
  network.join.kubernetes.enabled: true
  network.join.kubernetes.service-name: hazelcast-service
```

### Database Setup

#### PostgreSQL per Produzione
```sql
-- Creazione database e utente
CREATE DATABASE hazelcast_demo;
CREATE USER demo_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE hazelcast_demo TO demo_user;

-- Schema principale
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### H2 per Sviluppo
- **URL**: `jdbc:h2:mem:testdb`
- **Console**: http://localhost:8080/h2-console
- **Auto-creazione**: Schema generato automaticamente
- **Dati test**: Caricati via data.sql

### Hazelcast Config

#### Cluster Discovery
```java
@Configuration
public class HazelcastConfig {
    
    @Bean
    public Config hazelcastConfig() {
        Config config = new Config();
        config.setClusterName("hazelcast-demo-cluster");
        
        // Network configuration
        NetworkConfig network = config.getNetworkConfig();
        
        // Multicast per sviluppo
        if (isDevProfile()) {
            network.getJoin().getMulticastConfig().setEnabled(true);
        }
        
        // Kubernetes per produzione
        if (isProdProfile()) {
            network.getJoin().getKubernetesConfig().setEnabled(true);
        }
        
        return config;
    }
}
```

---

## 🚀 Deployment

### Docker Build

#### 1. Build Immagine
```dockerfile
# Multi-stage build
FROM openjdk:17-jdk-slim as build
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

FROM openjdk:17-jre-slim
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

```bash
# Build e test locale
docker build -t hazelcast-demo:latest .
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=dev hazelcast-demo:latest
```

#### 2. Registry Push
```bash
# Tag per registry
docker tag hazelcast-demo:latest your-registry/hazelcast-demo:v1.1.0

# Push
docker push your-registry/hazelcast-demo:v1.1.0
```

### OpenShift Local

#### Setup Automatico (⭐ Raccomandato)
```powershell
# Windows - Setup completo automatico
.\setup-openshift-local.ps1

# Il script eseguirà:
# 1. Verifica prerequisiti
# 2. Setup PostgreSQL
# 3. Deploy applicazione (2 repliche)
# 4. Configurazione networking
# 5. Test automatici
```

```bash
# Linux/Mac - Setup completo automatico  
./setup-openshift-local.sh
```

#### Setup Manuale

**1. Preparazione Cluster**
```bash
# Avvia OpenShift Local
crc start
eval $(crc oc-env)

# Crea progetto
oc new-project hazelcast-demo
```

**2. Deploy PostgreSQL**
```bash
# Deploy database
oc new-app postgresql-ephemeral \
  -p POSTGRESQL_USER=demo_user \
  -p POSTGRESQL_PASSWORD=demo_pass \
  -p POSTGRESQL_DATABASE=hazelcast_demo

# Verifica deploy
oc get pods -l name=postgresql
```

**3. Deploy Applicazione**
```bash
# Build da sorgenti
oc new-app https://github.com/antoniogalluzzi/hazelcast-demo-spring-boot \
  --name=hazelcast-demo

# Scaling cluster distribuito
oc scale deployment/hazelcast-demo --replicas=2

# Esposizione route
oc expose service/hazelcast-demo
```

**4. Configurazione Avanzata**
```yaml
# deployment.yaml - Configurazione completa
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hazelcast-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hazelcast-demo
  template:
    spec:
      containers:
      - name: hazelcast-demo
        image: hazelcast-demo:latest
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "prod"
        - name: DB_HOST
          value: "postgresql"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 30
```

#### 5. Verifica Deployment
```bash
# Status generale
oc get all

# Log applicazione
oc logs deployment/hazelcast-demo

# Test endpoint
APP_URL=$(oc get route hazelcast-demo -o jsonpath='{.spec.host}')
curl https://$APP_URL/actuator/health

# Test cache distribuita
curl https://$APP_URL/cache/stats
```

### Cloud Providers

#### AWS EKS
```bash
# Setup cluster
eksctl create cluster --name hazelcast-demo --region us-west-2

# Deploy con Helm
helm install hazelcast-demo ./k8s-chart \
  --set image.repository=your-account.dkr.ecr.us-west-2.amazonaws.com/hazelcast-demo \
  --set postgresql.host=your-rds-endpoint.amazonaws.com
```

#### Azure AKS  
```bash
# Setup cluster
az aks create --resource-group myResourceGroup --name hazelcast-demo-aks

# Deploy
kubectl apply -f k8s/
kubectl scale deployment hazelcast-demo --replicas=3
```

#### Google GKE
```bash
# Setup cluster
gcloud container clusters create hazelcast-demo-cluster --zone us-central1-a

# Deploy con auto-scaling
kubectl apply -f k8s/
kubectl autoscale deployment hazelcast-demo --cpu-percent=70 --min=2 --max=10
```

---

## 🧪 Testing

### Test Locali

#### Unit Tests
```bash
# Run test suite completa
./mvnw test

# Test specifici
./mvnw test -Dtest=UserControllerTest
./mvnw test -Dtest=CacheServiceTest
```

#### Integration Tests
```bash
# Test con database reale
./mvnw integration-test -Pintegration-tests

# Test cache distribuita
./mvnw test -Dtest=HazelcastIntegrationTest
```

### API Testing

#### Test Manuali con cURL

**1. Health Check**
```bash
# Basic health
curl http://localhost:8080/actuator/health

# Detailed health  
curl http://localhost:8080/actuator/health | jq '.'

# Response atteso:
{
  "status": "UP",
  "components": {
    "db": {"status": "UP"},
    "hazelcast": {"status": "UP"}
  }
}
```

**2. CRUD Operations**
```bash
# CREATE - Nuovo utente
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mario Rossi",
    "email": "mario.rossi@example.com"
  }' | jq '.'

# READ - Get utente (hit cache)
curl http://localhost:8080/user/1 | jq '.'

# UPDATE - Modifica utente
curl -X PUT http://localhost:8080/user/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mario Rossi Updated",
    "email": "mario.updated@example.com"
  }'

# DELETE - Rimuovi utente
curl -X DELETE http://localhost:8080/user/1
```

**3. Cache Testing**
```bash
# Statistiche cache
curl http://localhost:8080/cache/stats | jq '.'

# Informazioni cluster Hazelcast
curl http://localhost:8080/cache/cluster | jq '.'

# Clear cache
curl -X DELETE http://localhost:8080/cache/clear
```

#### Test con Postman

**Collection Setup:**
1. Import collection da `postman/Hazelcast-Demo.json`
2. Setup environment variables:
   - `base_url`: http://localhost:8080
   - `user_id`: 1

**Test Scenarios:**
- ✅ **Happy Path**: CRUD completo
- ✅ **Cache Performance**: Hit rate testing
- ✅ **Error Handling**: Validation errors
- ✅ **Load Testing**: Concurrent requests

#### Load Testing con JMeter

**Setup Test Plan:**
```xml
<!-- jmeter-test-plan.jmx -->
<TestPlan>
  <ThreadGroup>
    <elementProp name="ThreadGroup.main_controller">
      <LoopController>
        <intProp name="LoopController.loops">100</intProp>
      </LoopController>
    </elementProp>
    <stringProp name="ThreadGroup.num_threads">10</stringProp>
    <stringProp name="ThreadGroup.ramp_time">30</stringProp>
  </ThreadGroup>
</TestPlan>
```

**Execution:**
```bash
# Run load test
jmeter -n -t jmeter-test-plan.jmx -l results.jtl

# Analizza risultati
jmeter -g results.jtl -o report/
```

### Performance Testing

#### Metriche Chiave
- **Response Time**: < 100ms (cache hit)
- **Throughput**: > 1000 req/sec  
- **Cache Hit Rate**: > 80%
- **Memory Usage**: < 512MB per istanza

#### Test Cache Distribuita Multi-Istanza
```bash
# Terminal 1 - Prima istanza
SPRING_PROFILES_ACTIVE=dev SERVER_PORT=8080 ./mvnw spring-boot:run

# Terminal 2 - Seconda istanza  
SPRING_PROFILES_ACTIVE=dev SERVER_PORT=8081 ./mvnw spring-boot:run

# Test sincronizzazione cache
curl -X POST http://localhost:8080/user -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Verifica su seconda istanza (dovrebbe essere in cache)
curl http://localhost:8081/user/1

# Verifica statistiche cluster
curl http://localhost:8080/cache/cluster
curl http://localhost:8081/cache/cluster
```

---

## 🔧 Troubleshooting

### Problemi Comuni

#### 1. 🚨 Hazelcast Cluster Non Si Forma

**Sintomi:**
- Log: "Failed to connect to any address"
- Single node cluster invece di multi-node

**Soluzioni:**
```bash
# Verifica configurazione network
oc get pods -o wide
oc describe service hazelcast-demo

# Check multicast (sviluppo locale)
./mvnw spring-boot:run -Dhazelcast.network.join.multicast.enabled=true

# Debug Kubernetes discovery
oc logs deployment/hazelcast-demo | grep -i hazelcast
```

#### 2. 🚨 Database Connection Failed

**Sintomi:**
- "Connection refused" nei log
- Health check database DOWN

**Soluzioni:**
```bash
# Verifica PostgreSQL
oc get pods -l name=postgresql
oc port-forward service/postgresql 5432:5432

# Test connessione diretta
psql -h localhost -p 5432 -U demo_user -d hazelcast_demo

# Verifica variabili ambiente
oc get deployment hazelcast-demo -o yaml | grep -A 5 env:
```

#### 3. 🚨 Route/Ingress Non Raggiungibile

**Sintomi:**
- 404/502 su URL esterno
- Route esistente ma non funzionante

**Soluzioni:**
```bash
# Verifica route
oc get route hazelcast-demo -o yaml

# Test interno al cluster
oc rsh deployment/hazelcast-demo
curl http://localhost:8080/actuator/health

# Debug DNS (OpenShift Local)
# Aggiungi a C:\Windows\System32\drivers\etc\hosts:
# 192.168.130.11 hazelcast-demo-hazelcast-demo.apps-crc.testing
```

#### 4. 🚨 Performance Degradation

**Sintomi:**
- Response time elevati
- Cache hit rate basso

**Diagnostica:**
```bash
# Monitoring real-time
curl http://localhost:8080/actuator/metrics/cache.gets
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Thread dump analysis
curl http://localhost:8080/actuator/threaddump

# Heap dump (se necessario)
oc exec deployment/hazelcast-demo -- jcmd 1 GC.run_finalization
```

### Log Analysis

#### Configurazione Logging
```yaml
# logback-spring.xml
logging:
  level:
    com.hazelcast: DEBUG
    org.springframework.cache: DEBUG
    org.hibernate.SQL: DEBUG
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

#### Log Patterns da Monitorare
```bash
# Hazelcast cluster events
grep "Member.*added\|removed" app.log

# Cache operations
grep "Cache.*hit\|miss" app.log

# Database operations  
grep "Hibernate:" app.log

# Errors critici
grep -i "error\|exception\|failed" app.log
```

### Debug Guide

#### Remote Debugging
```bash
# Avvio con debug abilitato
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"

# Connect da IDE su porta 5005
```

#### Profiling Tools
- **VisualVM**: Monitoring JVM real-time
- **JProfiler**: Advanced profiling  
- **Micrometer**: Custom metrics
- **Actuator**: Built-in endpoints

---

## 📋 Riferimenti

### API Reference

#### Endpoints Principali

| Endpoint | Method | Descrizione | Body |
|----------|---------|-------------|------|
| `/user` | GET | Lista tutti utenti | - |
| `/user/{id}` | GET | Get utente per ID | - |
| `/user` | POST | Crea nuovo utente | `{"name": "string", "email": "string"}` |
| `/user/{id}` | PUT | Aggiorna utente | `{"name": "string", "email": "string"}` |
| `/user/{id}` | DELETE | Elimina utente | - |
| `/cache/stats` | GET | Statistiche cache | - |
| `/cache/cluster` | GET | Info cluster Hazelcast | - |
| `/cache/clear` | DELETE | Pulisci cache | - |

#### Actuator Endpoints

| Endpoint | Descrizione |
|----------|-------------|
| `/actuator/health` | Health check generale |
| `/actuator/health/readiness` | Readiness probe |
| `/actuator/health/liveness` | Liveness probe |
| `/actuator/metrics` | Lista metriche disponibili |
| `/actuator/metrics/{metric}` | Metrica specifica |
| `/actuator/info` | Informazioni applicazione |
| `/actuator/env` | Variabili ambiente |

#### Response Examples

**GET /user/1 - Success (200)**
```json
{
  "id": 1,
  "name": "Mario Rossi",
  "email": "mario.rossi@example.com",
  "createdAt": "2025-09-01T10:00:00Z"
}
```

**GET /cache/stats - Success (200)**  
```json
{
  "cacheSize": 45,
  "hitCount": 123,
  "missCount": 23,
  "hitRate": 0.84,
  "clusterSize": 2,
  "localMemoryUsage": "15MB"
}
```

### Changelog

#### [2.0.0] - 2025-09-01 (Corrente)

**Added:**
- ✅ **Documentazione Unificata**: Consolidati 9 file in unico documento completo
- ✅ **Guide Progressive**: Da quick start a deployment avanzato
- ✅ **Troubleshooting Completo**: Problemi comuni e soluzioni
- ✅ **API Reference**: Documentazione completa endpoint

**Changed:**
- 🔄 **Struttura Semplificata**: Navigazione lineare e intuitiva
- 🔄 **Esempi Pratici**: Comandi copy-paste per ogni scenario

**Fixed:**  
- 🐛 **Link Rotti**: Corretti tutti i riferimenti interni
- 🐛 **Caratteri Corrotti**: Sistemate emoji e formattazione

#### [1.1.0] - 2025-09-01

**Added:**
- ✅ **Configurazione DNS OpenShift Local**
- ✅ **Script Setup Automatico**  
- ✅ **Testing Suite Completa**
- ✅ **RBAC Security**

**Changed:**
- 🔄 **Deployment Guide**: Procedure step-by-step
- 🔄 **Cache Configuration**: Ottimizzazioni performance

#### [1.0.0] - 2025-08-30

**Added:**
- ✅ **Release Iniziale**
- ✅ **Spring Boot + Hazelcast + PostgreSQL**
- ✅ **OpenShift Support**
- ✅ **Docker Containerization**

### Licenza

```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Copyright 2025 Antonio Galluzzi
```

---

## 🎉 Conclusione

Questo progetto fornisce una **base solida e completa** per applicazioni enterprise che richiedono:

- ✅ **Cache distribuita ad alte performance**
- ✅ **Scalabilità orizzontale automatica**  
- ✅ **Deploy cloud-native**
- ✅ **Monitoring e osservabilità**
- ✅ **Testing automatizzato**

**🚀 Prossimi passi consigliati:**
1. Setup ambiente sviluppo locale  
2. Esplora API con Swagger UI
3. Deploy su OpenShift Local
4. Integrazione CI/CD pipeline
5. Estensione con nuove funzionalità

**💡 Hai domande o suggerimenti?**  
Apri una issue su GitHub o contatta direttamente: antonio.galluzzi91@gmail.com

**Happy coding!** 🚀
