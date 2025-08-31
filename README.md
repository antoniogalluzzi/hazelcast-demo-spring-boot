# Ha## 👤 Autore

**Antonio Galluzzi**
- **GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)
- **Email**: antonio.galluzzi91@gmail.com
- **Ruolo**: Sviluppatore e Manutentore

## 📄 Licenza

Questo progetto è distribuito sotto licenza **Apache License 2.0**.

Vedi il file [LICENSE](LICENSE) per i dettagli completi sulla licenza.

Copyright 2025 Antonio Galluzzi

## 📋 Registro delle ModificheDemo Project

Questo progetto dimostra l'uso di Spring Boot con Hazelcast per la cache distribuita e PostgreSQL come database su OpenShift.

## � Autore

**Antonio Galluzzi**
- **GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)
- **Email**: antonio.galluzzi@example.com
- **Ruolo**: Sviluppatore e Manutentore

## �📋 Registro delle Modifiche

Vedi [CHANGELOG.md](CHANGELOG.md) per il registro completo delle modifiche e aggiornamenti del progetto.

## Prerequisiti

- Java 21
- Maven
- Docker
- OpenShift CLI (oc)
- Cluster OpenShift su AWS (ROSA)

## Build

```bash
mvn clean package -DskipTests
```

## Docker

Costruisci l'immagine Docker:

```bash
docker build -t hazelcast-demo .
```

Push su registry (es. OpenShift registry o ECR):

```bash
docker tag hazelcast-demo <registry>/hazelcast-demo:latest
docker push <registry>/hazelcast-demo:latest
```

## 🚀 Deploy su OpenShift Local

OpenShift Local (precedentemente CodeReady Containers) permette di testare l'applicazione localmente prima del deploy in produzione.

### Setup Automatico (Raccomandato)

#### Linux/macOS
```bash
# Rendi eseguibile e avvia setup
chmod +x setup-openshift-local.sh
./setup-openshift-local.sh start    # Avvia CRC e configura
./setup-openshift-local.sh deploy   # Deploy database e app
./setup-openshift-local.sh test     # Test applicazione
```

#### Windows
```powershell
# Avvia setup
.\setup-openshift-local.ps1 -Command start    # Avvia CRC e configura
.\setup-openshift-local.ps1 -Command deploy   # Deploy database e app
.\setup-openshift-local.ps1 -Command test     # Test applicazione
```

### Setup Manuale

#### Comandi Script Disponibili

```bash
# Linux/macOS
./setup-openshift-local.sh start     # Avvia CRC e configura ambiente
./setup-openshift-local.sh deploy    # Deploy completo (DB + App)
./setup-openshift-local.sh test      # Test automatici dell'applicazione
./setup-openshift-local.sh info      # Mostra info applicazione
./setup-openshift-local.sh cleanup   # Pulizia completa

# Windows PowerShell
.\setup-openshift-local.ps1 -Command start
.\setup-openshift-local.ps1 -Command deploy
.\setup-openshift-local.ps1 -Command test
.\setup-openshift-local.ps1 -Command info
.\setup-openshift-local.ps1 -Command cleanup
```

### Workflow di Sviluppo

```bash
# 1. Avvia ambiente locale
./setup-openshift-local.sh start

# 2. Deploy applicazione
./setup-openshift-local.sh deploy

# 3. Sviluppa e testa
# Modifica codice → Build → Deploy
oc start-build hazelcast-demo --from-dir=. --follow

# 4. Test automatico
./setup-openshift-local.sh test

# 5. Monitora
oc logs -f deployment/hazelcast-demo
```

### Prerequisiti OpenShift Local

- **Sistema operativo**: Windows 10/11 Pro/Enterprise, macOS, Linux
- **RAM**: Minimo 8GB, raccomandati 16GB+
- **CPU**: Minimo 4 core, raccomandati 6+ core
- **Disco**: 35GB liberi
- **Virtualizzazione**: Hyper-V (Windows), Hypervisor Framework (macOS), KVM (Linux)

### Installazione OpenShift Local

#### Windows
```bash
# Scarica da https://console.redhat.com/openshift/create/local
# Installa il CRC (CodeReady Containers)
# Esegui come amministratore
crc setup
crc start
```

#### macOS/Linux
```bash
# Scarica da https://console.redhat.com/openshift/create/local
# Installa e configura
crc setup
crc start
```

### Configurazione OpenShift Local

```bash
# Login al cluster
oc login -u kubeadmin -p $(crc console --credentials | grep Password | awk '{print $2}') https://api.crc.testing:6443

# Crea progetto
oc new-project hazelcast-demo-local

# Verifica stato cluster
oc get nodes
oc get pv  # Verifica storage disponibile
```

### Deploy Database (PostgreSQL)

```bash
# Deploy PostgreSQL usando template OpenShift
oc new-app postgresql-ephemeral \
  --param DATABASE_SERVICE_NAME=postgresql \
  --param POSTGRESQL_DATABASE=hazelcastdb \
  --param POSTGRESQL_USER=hazelcast \
  --param POSTGRESQL_PASSWORD=hazelcast123 \
  --param POSTGRESQL_VERSION=13

# Attendi che il pod sia ready
oc get pods -w
```

### Deploy Applicazione

```bash
# Crea secret per database
oc create secret generic db-secret \
  --from-literal=host=postgresql.hazelcast-demo-local.svc.cluster.local \
  --from-literal=dbname=hazelcastdb \
  --from-literal=username=hazelcast \
  --from-literal=password=hazelcast123

# Build immagine usando S2I (Source-to-Image)
oc new-build --name=hazelcast-demo --binary --image-stream=java:openjdk-21-ubi8:latest
oc start-build hazelcast-demo --from-dir=. --follow

# Deploy applicazione
oc new-app hazelcast-demo:latest \
  --name=hazelcast-demo \
  --env=DB_HOST=postgresql.hazelcast-demo-local.svc.cluster.local \
  --env=DB_NAME=hazelcastdb \
  --env=DB_USERNAME=hazelcast \
  --env=DB_PASSWORD=hazelcast123

# Scala a 2 repliche per test cache distribuita
oc scale deployment hazelcast-demo --replicas=2
```

### Deploy con YAML (Metodo Alternativo)

```bash
# Modifica deployment.yaml per ambiente locale
# Cambia l'immagine in: image: hazelcast-demo:latest
# Rimuovi riferimenti a ConfigMap esterni

# Deploy
oc apply -f deployment.yaml
```

### Accesso all'Applicazione

```bash
# Ottieni route
oc get routes

# Test API
curl http://hazelcast-demo-hazelcast-demo-local.apps-crc.testing/user/1

# Apri Swagger UI
open http://hazelcast-demo-hazelcast-demo-local.apps-crc.testing/swagger-ui.html
```

### Deploy Monitoring (Opzionale)

```bash
# Deploy Grafana
oc apply -f grafana-deployment.yaml

# Accesso Grafana
oc get routes grafana-route

# Default credentials: admin/admin
```

### Troubleshooting OpenShift Local

#### Problema: CRC non si avvia
```bash
# Verifica risorse sistema
crc status

# Pulisci e riavvia
crc cleanup
crc setup
crc start
```

#### Problema: Build fallisce
```bash
# Verifica logs build
oc logs -f bc/hazelcast-demo

# Ricostruisci
oc start-build hazelcast-demo --from-dir=. --follow
```

#### Problema: Database non accessibile
```bash
# Verifica servizio PostgreSQL
oc get pods
oc logs postgresql-1-abcde

# Test connessione
oc rsh postgresql-1-abcde psql -h localhost -U hazelcast hazelcastdb
```

#### Problema: Applicazione non risponde
```bash
# Verifica pod status
oc get pods
oc describe pod hazelcast-demo-xyz

# Controlla logs applicazione
oc logs -f deployment/hazelcast-demo

# Verifica health check
curl http://localhost:8080/actuator/health
```

### Pulizia Ambiente Locale

```bash
# Rimuovi tutto
oc delete project hazelcast-demo-local

# Stop CRC
crc stop

# Cleanup completo (opzionale)
crc cleanup
```

## Deploy su OpenShift

1. Crea un progetto su OpenShift (o usa quello esistente):
   ```bash
   oc new-project contactcenter-dev
   ```

2. Crea un Secret per il DB:
   ```bash
   oc create secret generic db-secret \
     --from-literal=host=<postgresql-service> \
     --from-literal=dbname=hazelcastdb \
     --from-literal=username=<username> \
     --from-literal=password=<password>
   ```

3. Deploy PostgreSQL (usa template OpenShift):
   ```bash
   oc new-app postgresql-ephemeral \
     --param DATABASE_SERVICE_NAME=postgresql \
     --param POSTGRESQL_DATABASE=hazelcastdb \
     --param POSTGRESQL_USER=<username> \
     --param POSTGRESQL_PASSWORD=<password>
   ```

4. Applica il deployment (include ServiceAccount, RBAC, ConfigMap, health checks):
   ```bash
   oc apply -f deployment.yaml
   ```

5. Scala a 4 repliche:
   ```bash
   oc scale deployment hazelcast-demo --replicas=4
   ```

6. Ottieni la route per testare:
   ```bash
   oc get routes
   ```

## Test

Una volta deployato, ottieni la route:

```bash
oc get routes
```

Testa gli endpoint:

1. Crea un utente:
   ```bash
   curl -X POST <route-url>/user -H "Content-Type: application/json" -d '{"name":"John Doe"}'
   ```

2. Recupera l'utente:
   ```bash
   curl <route-url>/user/1
   ```

La cache distribuita funziona tra le repliche via Hazelcast Kubernetes discovery.

### Test Grafana

1. **Accedi a Grafana**:
   ```bash
   oc get routes grafana-route
   ```

2. **Verifica DataSource**:
   - Vai su Configuration → Data Sources
   - Verifica che Prometheus sia connesso

3. **Importa Dashboard**:
   - Vai su Create → Import
   - Carica `grafana-dashboard.json`
   - Seleziona il DataSource Prometheus

4. **Test metriche**:
   - Genera traffico: `curl <route-url>/user/1`
   - Osserva i grafici aggiornarsi in tempo reale

5. **Verifica pannelli**:
   - JVM Memory Usage
   - HTTP Request Rate
   - Hazelcast Cache Operations
   - Database Connections

## Architettura

- **Spring Boot**: Framework per API REST e integrazione.
- **Hazelcast**: Cache distribuita con discovery automatico su Kubernetes.
- **PostgreSQL**: Database condiviso per persistenza.
- **Prometheus**: Monitoraggio metriche (integrato con Micrometer).
- **Grafana**: Dashboard per visualizzazione metriche e monitoraggio.
- **Fluentd/Elasticsearch**: Logging centralizzato strutturato in JSON.
- **OpenShift**: Piattaforma per deploy, scaling e gestione.
- **RBAC**: ServiceAccount per accesso API Kubernetes.
- **Health Checks**: Readiness/Liveness per monitoraggio.

## API Endpoints

- `POST /user`: Crea un utente (salva su DB).
- `GET /user/{id}`: Recupera utente (cache distribuita).
- `GET /actuator/health`: Health check.
- `GET /actuator/prometheus`: Metriche Prometheus.

## Monitoring

Il progetto include integrazione con Prometheus per monitoraggio delle metriche:

- **Metriche esposte**: `/actuator/prometheus` fornisce metriche JVM, Spring Boot, Hazelcast e database.
- **Scrape automatico**: Il Service ha annotazioni per Prometheus integrato in OpenShift.
- **Dashboard Grafana**: Visualizzazione avanzata delle metriche con dashboard preconfigurate.

### Configurazione Grafana su OpenShift

**Opzione 1: Deploy automatico con YAML**

```bash
oc apply -f grafana-deployment.yaml
```

**Opzione 2: Installazione manuale**

1. **Installa Grafana Operator** (se non presente):
   ```bash
   oc apply -f https://raw.githubusercontent.com/integr8ly/grafana-operator/master/deploy/crds/Grafana.yaml
   oc apply -f https://raw.githubusercontent.com/integr8ly/grafana-operator/master/deploy/roles/ClusterRole.yaml
   oc apply -f https://raw.githubusercontent.com/integr8ly/grafana-operator/master/deploy/roles/ClusterRoleBinding.yaml
   oc apply -f https://raw.githubusercontent.com/integr8ly/grafana-operator/master/deploy/operator.yaml
   ```

2. **Crea istanza Grafana**:
   ```bash
   cat <<EOF | oc apply -f -
   apiVersion: integreatly.org/v1alpha1
   kind: Grafana
   metadata:
     name: grafana
     namespace: contactcenter-dev
   spec:
     config:
       log:
         mode: "console"
         level: "warn"
       auth:
         disable_login_form: False
       auth.anonymous:
         enabled: True
   EOF
   ```

3. **Crea DataSource per Prometheus**:
   ```bash
   cat <<EOF | oc apply -f -
   apiVersion: integreatly.org/v1alpha1
   kind: GrafanaDataSource
   metadata:
     name: prometheus
     namespace: contactcenter-dev
   spec:
     name: prometheus.yaml
     datasources:
     - name: Prometheus
       type: prometheus
       access: proxy
       url: http://prometheus-operated:9090
       isDefault: true
   EOF
   ```

4. **Importa Dashboard**:
   - Accedi a Grafana tramite la route: `oc get routes`
   - Vai su "Create" → "Import"
   - Carica il file `grafana-dashboard.json` dal repository

### Metriche disponibili in Grafana

- **JVM Metrics**: Heap usage, GC pauses, thread count
- **Spring Boot**: HTTP requests, response times, error rates
- **Hazelcast**: Cache hits/misses, cluster size, operations
- **Database**: Connection pools, query performance
- **Pod Metrics**: CPU, memory, network I/O

Per accedere alle metriche:

```bash
curl <route-url>/actuator/prometheus
```

## Logging Centralizzato

Il progetto include logging strutturato per sistemi centralizzati:

- **Formato JSON**: Log in formato JSON per Elasticsearch/Fluentd
- **Contesto Kubernetes**: MDC con namespace, pod name, service
- **Livelli configurati**: DEBUG per app, INFO per framework, WARN per DB
- **Fluentd integrato**: OpenShift raccoglie automaticamente i log

### Visualizzazione logs:

```bash
# Logs del pod specifico
oc logs <pod-name> -f

# Logs di tutti i pod dell'app
oc logs -l app=hazelcast-demo -f

# Logs con Fluentd/Elasticsearch (se configurato)
# Accedi alla console OpenShift -> Logging -> Logs
```

### Configurazione MDC:

I log includono automaticamente:
- `timestamp`: Data/ora in formato ISO
- `level`: Livello log (INFO, DEBUG, WARN, ERROR)
- `logger`: Classe che ha generato il log
- `thread`: Thread che ha eseguito il codice
- `message`: Messaggio del log
- `pod_name`: Nome del pod Kubernetes
- `namespace`: Namespace Kubernetes
- `service`: Nome servizio
- `host`: Hostname del container

## Troubleshooting

- **Errore DB**: Verifica Secret `db-secret` e servizio PostgreSQL.
- **Cluster Hazelcast**: Controlla logs per "Members" e namespace.
- **Route non accessibile**: Usa `oc get routes` e verifica exposure.
- **Pods non ready**: Controlla health checks e risorse (memory/CPU).
- **Grafana non mostra metriche**: Verifica che Prometheus sia raggiungibile e che il DataSource sia configurato correttamente.
- **Dashboard vuota**: Controlla che le metriche siano esposte su `/actuator/prometheus` e che i job names corrispondano.
- **Grafana Operator non installato**: Esegui i comandi di installazione dell'operator prima di creare l'istanza Grafana.

## Note

- Sostituisci `<your-registry>` con il tuo registry Docker.
- Sostituisci `<postgresql-service>`, `<username>`, `<password>` con valori reali.
- Monitoring Prometheus incluso per metriche JVM, Spring Boot, Hazelcast e database.
- Dashboard Grafana inclusa per visualizzazione avanzata delle metriche.
- Logging centralizzato incluso con Fluentd/Elasticsearch per OpenShift.

---

# 📚 Documentazione Avanzata

## API Documentation

### Swagger UI
Una volta avviata l'applicazione, la documentazione interattiva API è disponibile su:
- **Locale**: http://localhost:8080/swagger-ui.html
- **OpenShift**: `https://<route-url>/swagger-ui.html`

### OpenAPI Specification
- **JSON**: `/v3/api-docs`
- **YAML**: `/v3/api-docs.yaml`

### Endpoint Documentati
- `GET /user/{id}` - Recupera utente con cache distribuita
- `POST /user` - Crea nuovo utente
- `GET /cache` - Test cache
- `GET /actuator/health` - Health check
- `GET /actuator/prometheus` - Metriche Prometheus

## 🏗️ Architettura Dettagliata

### Componenti Core
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Spring Boot   │    │   Hazelcast     │    │  PostgreSQL     │
│   REST API      │◄──►│  Distributed    │◄──►│   Database      │
│                 │    │    Cache        │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │    │    Grafana      │    │  Fluentd/ES     │
│   Metrics       │    │   Dashboard     │    │   Logging       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Flusso Dati
1. **Prima richiesta**: DB → Cache → Client
2. **Richieste successive**: Cache → Client
3. **Aggiornamenti**: DB + Cache invalidation
4. **Metriche**: Prometheus scraping
5. **Logs**: Fluentd → Elasticsearch

### Cache Strategy
- **Read-Through**: Caricamento automatico dalla cache
- **Write-Through**: Scrittura simultanea su DB e cache
- **TTL**: 30 minuti per dati utente
- **Eviction**: LRU policy

## ⚙️ Configurazione Avanzata

### Hazelcast Configuration
```yaml
hazelcast:
  cluster-name: hazelcast-demo-cluster
  network:
    join:
      kubernetes:
        enabled: true
        namespace: ${KUBERNETES_NAMESPACE}
        service-name: hazelcast-demo-service
  map:
    users:
      time-to-live-seconds: 1800  # 30 minuti
      max-idle-seconds: 600       # 10 minuti
      eviction:
        eviction-policy: LRU
        max-size-policy: USED_HEAP_SIZE
        size: 50
```

### Database Optimization
```properties
# Connection Pool
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.connection-timeout=30000

# JPA Optimization
spring.jpa.properties.hibernate.jdbc.batch_size=25
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
spring.jpa.properties.hibernate.jdbc.batch_versioned_data=true

# Query Logging (solo development)
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.format_sql=true
```

### JVM Tuning
```bash
# Production JVM settings
java -server \
  -Xms512m -Xmx1024m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:+PrintGCDetails \
  -XX:+PrintGCTimeStamps \
  -jar hazelcast-demo.jar
```

## 🚀 Performance Tuning

### Cache Performance
- **Hit Ratio Target**: > 90%
- **Latency Target**: < 10ms per richiesta
- **Throughput**: 1000+ req/sec per pod

### Database Optimization
```sql
-- Indexes raccomandati
CREATE INDEX idx_users_name ON users(name);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Query optimization
EXPLAIN ANALYZE SELECT * FROM users WHERE id = $1;
```

### Monitoring Queries
```promql
# Cache Hit Rate
rate(hazelcast_cache_hits_total[5m]) / rate(hazelcast_cache_gets_total[5m])

# Response Time P95
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# Database Connections
hikaricp_connections_active
```

## 🔒 Sicurezza

### Best Practices
- **Secrets Management**: Usa OpenShift Secrets per credenziali
- **Network Policies**: Limita traffico tra pod
- **RBAC**: ServiceAccount con minimi privilegi
- **TLS**: Abilita HTTPS per tutte le comunicazioni

### Security Headers
```yaml
# application.properties
server.servlet.session.cookie.secure=true
server.servlet.session.cookie.http-only=true
server.servlet.session.cookie.same-site=strict
```

### Database Security
```sql
-- Crea utente con privilegi limitati
CREATE USER hazelcast_app WITH PASSWORD 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO hazelcast_app;
GRANT USAGE ON SEQUENCE users_id_seq TO hazelcast_app;
```

## 🔧 Troubleshooting Avanzato

### Cache Issues
```bash
# Verifica cluster Hazelcast
oc exec -it <pod-name> -- bash
curl http://localhost:5701/hazelcast/health

# Verifica cache statistics
oc logs <pod-name> | grep "cache"
```

### Database Issues
```bash
# Connection pool status
curl http://localhost:8080/actuator/metrics/hikaricp.connections.active

# Database connectivity
oc exec -it <pod-name> -- pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USERNAME
```

### Performance Issues
```bash
# JVM heap usage
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Thread dump
oc exec -it <pod-name> -- jstack 1 > threaddump.txt
```

### Logging Issues
```bash
# Fluentd logs
oc logs -l app=fluentd

# Elasticsearch cluster health
curl http://elasticsearch:9200/_cluster/health
```

## 📊 Metriche Chiave

### Business Metrics
- **User Creation Rate**: `rate(user_creations_total[5m])`
- **Cache Hit Rate**: `rate(hazelcast_cache_hits_total[5m]) / rate(hazelcast_cache_gets_total[5m])`
- **Average Response Time**: `histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))`

### System Metrics
- **Pod CPU Usage**: `rate(container_cpu_usage_seconds_total[5m])`
- **Pod Memory Usage**: `container_memory_usage_bytes`
- **Database Connections**: `hikaricp_connections_active`

### Hazelcast Metrics
- **Cluster Size**: `hazelcast_cluster_size`
- **Cache Size**: `hazelcast_cache_size`
- **Operations Rate**: `rate(hazelcast_cache_gets_total[5m])`

## 🚀 Deployment Strategies

### Blue-Green Deployment
```bash
# Crea nuovo deployment
oc apply -f deployment-v2.yaml

# Switch traffic
oc patch route hazelcast-demo -p '{"spec":{"to":{"name":"hazelcast-demo-v2"}}}'

# Rollback if needed
oc patch route hazelcast-demo -p '{"spec":{"to":{"name":"hazelcast-demo-v1"}}}'
```

### Canary Deployment
```bash
# Deploy canary
oc apply -f deployment-canary.yaml

# Gradual traffic increase
oc patch route hazelcast-demo -p '{"spec":{"alternateBackends":[{"name":"hazelcast-demo-canary","weight":10}]}}'
```

### Rolling Update
```bash
# Zero-downtime update
oc rollout restart deployment/hazelcast-demo

# Monitor rollout
oc rollout status deployment/hazelcast-demo
```

## 📈 Scalabilità

### Horizontal Pod Autoscaling
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hazelcast-demo-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hazelcast-demo
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Hazelcast Scaling
- **Auto-discovery**: Kubernetes service discovery
- **Dynamic scaling**: Automatic cluster reconfiguration
- **Data partitioning**: Consistent hashing across nodes

## 🔄 Backup & Recovery

### Database Backup
```bash
# Backup PostgreSQL
oc exec -it postgresql-pod -- pg_dump -U postgres hazelcastdb > backup.sql

# Restore
oc exec -it postgresql-pod -- psql -U postgres hazelcastdb < backup.sql
```

### Cache Backup
```yaml
# Hazelcast Map Store (persistent cache)
hazelcast:
  map:
    users:
      map-store:
        enabled: true
        class-name: com.example.hazelcastdemo.UserMapStore
        write-delay-seconds: 0
```

## 📚 Risorse Aggiuntive

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Hazelcast Documentation](https://docs.hazelcast.com/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Environment Configurations](./environment-configs.md) - Configurazioni per dev/staging/prod (documentazione)
- [API Testing Guide](./api-testing.md) - Esempi di test per l'API
- [Cloud Deployment Guide](./cloud-deployment.md) - Deployment su AWS EKS, GKE, AKS
- [OpenShift Local Guide](./openshift-local-guide.md) - Sviluppo e test locale con CRC
- [Setup Scripts](./setup-openshift-local.sh) - Script automatizzati per Linux/macOS
- [Setup Scripts (Windows)](./setup-openshift-local.ps1) - Script automatizzati per Windows
- [Quick Test Commands](./quick-test-commands.sh) - Comandi rapidi per test e debug

---

## 📁 Configurazioni per Ambiente

### File di Configurazione Disponibili

Il progetto include configurazioni ottimizzate per diversi ambienti:

- **`src/main/resources/application.properties`** - Configurazione base (default)
- **`src/main/resources/application-dev.yml`** - Ambiente di sviluppo
- **`src/main/resources/application-staging.yml`** - Ambiente di staging
- **`src/main/resources/application-prod.yml`** - Ambiente di produzione

### Come Usare Diversi Ambienti

```bash
# Sviluppo locale
./mvnw spring-boot:run -Dspring.profiles.active=dev

# Staging
java -jar target/hazelcast-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=staging

# Produzione
java -jar target/hazelcast-demo-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod
```

### Variabili d'Ambiente per Produzione

```bash
export DB_HOST=your-postgres-host
export DB_PORT=5432
export DB_NAME=hazelcastdb
export DB_USERNAME=your-username
export DB_PASSWORD=your-password
export KUBERNETES_NAMESPACE=your-namespace
```

### ❗ Il File `environment-configs.yml`

**IMPORTANTE:** Il file `environment-configs.yml` nella root del progetto **NON è un file di configurazione** da usare direttamente!

Questo file serve solo come:
- 📚 **Documentazione** - Mostra esempi di configurazione per ogni ambiente
- 📋 **Reference** - Guida per capire le differenze tra ambienti
- 🔧 **Template** - Base per creare i veri file di configurazione

**Usa invece i file in `src/main/resources/` per le configurazioni reali!**
