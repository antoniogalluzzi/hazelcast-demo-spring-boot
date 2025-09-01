# Hazelcast Demo Project

Questo progetto dimostra l'uso di Spring Boot con Hazelcast per la cache distribuita e PostgreSQL come database su OpenShift.

## � Indice

- [👤 Autore](#-autore)
- [📄 Licenza](#-licenza)
- [📋 Registro delle Modifiche](#-registro-delle-modifiche)
- [Prerequisiti](#prerequisiti)
- [💻 Sviluppo Locale con H2](#-sviluppo-locale-con-h2)
  - [Configurazione H2](#configurazione-h2)
  - [Avvio in Modalità Sviluppo](#avvio-in-modalità-sviluppo)
  - [Accesso alla Console H2](#accesso-alla-console-h2)
  - [Caratteristiche H2 per Sviluppo](#caratteristiche-h2-per-sviluppo)
  - [Test delle API con H2](#test-delle-api-con-h2)
  - [Transizione Produzione](#transizione-produzione)
- [Build](#build)
- [Docker](#docker)
- [🚀 Deploy su OpenShift Local](#-deploy-su-openshift-local)
  - [Setup Automatico (Raccomandato)](#setup-automatico-raccomandato)
  - [Setup Manuale](#setup-manuale)
- [🧪 Test e Validazione](#-test-e-validazione)
  - [Test Cache Distribuita Multi-Istanza](#test-cache-distribuita-multi-istanza)
  - [Test API REST](#test-api-rest)
  - [Test Compilazione e Build](#test-compilazione-e-build)
  - [Test Logging e Monitoraggio](#test-logging-e-monitoraggio)
  - [Test Database](#test-database)
  - [Test Sicurezza e Configurazione](#test-sicurezza-e-configurazione)
- [📚 Documentazione Avanzata](#-documentazione-avanzata)
  - [API Documentation](#api-documentation)

## �👤 Autore

**Antonio Galluzzi**
- **GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)
- **Email**: antonio.galluzzi91@gmail.com
- **Ruolo**: Sviluppatore e Manutentore

## 📄 Licenza

Questo progetto è distribuito sotto licenza **Apache License 2.0**.

Vedi il file [LICENSE](LICENSE) per i dettagli completi sulla licenza.

Copyright 2025 Antonio Galluzzi

## 📋 Registro delle Modifiche

Vedi [CHANGELOG.md](CHANGELOG.md) per il registro completo delle modifiche e aggiornamenti del progetto.

## Prerequisiti

- Java 21
- Maven
- Docker
- OpenShift CLI (oc)
- Cluster OpenShift su AWS (ROSA)

## 💻 Sviluppo Locale con H2

Per lo sviluppo locale, il progetto utilizza **H2 Database** (database in-memory) invece di PostgreSQL per semplicità e velocità.

### Configurazione H2

Il profilo `dev` configura automaticamente H2 con le seguenti impostazioni:

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
    driverClassName: org.h2.Driver
    username: sa
    password:  # (vuoto)
  jpa:
    database-platform: org.hibernate.dialect.H2Dialect
    show-sql: true
    hibernate:
      ddl-auto: create-drop
  h2:
    console:
      enabled: true
```


### Avvio in Modalità Sviluppo

#### Per Linux/Mac (Bash)
```bash
# Avvia l'applicazione con profilo dev (H2)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

#### Per Windows (PowerShell)
```powershell
# Avvia l'applicazione con profilo dev (H2)
./maven/bin/mvn.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

### Accesso alla Console H2

Una volta avviata l'applicazione, la console H2 è disponibile su:
- **URL**: `http://localhost:8080/h2-console`
- **JDBC URL**: `jdbc:h2:mem:testdb`
- **Username**: `sa`
- **Password**: *(lascia vuoto)*

### Caratteristiche H2 per Sviluppo

- **In-Memory**: I dati vengono persi al riavvio dell'applicazione
- **Auto-Create**: Le tabelle vengono create automaticamente da Hibernate
- **SQL Logging**: Le query SQL vengono mostrate nei log
- **Console Web**: Interfaccia grafica per interrogare il database
- **Rapido**: Nessuna dipendenza esterna da installare

### Test delle API con H2

```bash
# Crea un utente
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name":"Mario Rossi"}'

# Recupera l'utente (dalla cache)
curl http://localhost:8080/user/1

# Verifica health
curl http://localhost:8080/actuator/health
```

### Transizione Produzione

Quando si passa alla produzione, il profilo cambia automaticamente a PostgreSQL:
- **Dev**: H2 in-memory (profilo `dev`)
- **Staging**: PostgreSQL containerizzato (profilo `staging`)
- **Prod**: PostgreSQL su OpenShift (profilo `prod`)


## Build

#### Per Linux/Mac (Bash)
```bash
mvn clean package -DskipTests
```

#### Per Windows (PowerShell)
```powershell
mvnw.cmd clean package -DskipTests
```


## Docker

Costruisci l'immagine Docker:

#### Per Linux/Mac (Bash)
```bash
docker build -t hazelcast-demo .
docker tag hazelcast-demo <registry>/hazelcast-demo:latest
docker push <registry>/hazelcast-demo:latest
```

#### Per Windows (PowerShell)
```powershell
docker build -t hazelcast-demo .
docker tag hazelcast-demo <registry>/hazelcast-demo:latest
docker push <registry>/hazelcast-demo:latest
```

## 🚀 Deploy su OpenShift Local

OpenShift Local (precedentemente CodeReady Containers) permette di testare l'applicazione localmente prima del deploy in produzione.


### Setup Automatico (Raccomandato)

#### Per Linux/Mac (Bash)
```bash
# Rendi eseguibile e avvia setup
chmod +x setup-openshift-local.sh
./setup-openshift-local.sh start    # Avvia CRC e configura
./setup-openshift-local.sh deploy   # Deploy database e app
./setup-openshift-local.sh test     # Test applicazione
```

#### Per Windows (PowerShell)
```powershell
# Esegui setup PowerShell
./setup-openshift-local.ps1 -Command start    # Avvia CRC e configura
./setup-openshift-local.ps1 -Command deploy   # Deploy database e app
./setup-openshift-local.ps1 -Command test     # Test applicazione
```


### Setup Manuale

#### Per Linux/Mac (Bash)
```bash
./setup-openshift-local.sh start     # Avvia CRC e configura ambiente
./setup-openshift-local.sh deploy    # Deploy completo (DB + App)
./setup-openshift-local.sh test      # Test automatici dell'applicazione
./setup-openshift-local.sh info      # Mostra info applicazione
./setup-openshift-local.sh cleanup   # Pulizia completa
```

#### Per Windows (PowerShell)
```powershell
./setup-openshift-local.ps1 -Command start
./setup-openshift-local.ps1 -Command deploy
./setup-openshift-local.ps1 -Command test
./setup-openshift-local.ps1 -Command info
./setup-openshift-local.ps1 -Command cleanup
```

## 🧪 Test e Validazione

Il progetto include una suite completa di test per validare funzionalità e performance.

### Test Cache Distribuita Multi-Istanza

#### ✅ Test Completati
- **Avvio Multi-Istanza**: Porte 8080/8081 funzionanti
- **Cluster Hazelcast**: 2 membri uniti correttamente
- **Cache Distribuita**: Sincronizzazione automatica tra istanze
- **API REST**: Funzionanti su entrambe le istanze
- **Multicast Discovery**: Auto-rilevamento funzionante

#### 📊 Risultati Test
- ✅ **Sincronizzazione Cache**: Dati condivisi tra istanze
- ✅ **Performance**: Accesso dalla cache invece che dal DB
- ✅ **Scalabilità**: Architettura distribuita funzionante
- ✅ **Fault Tolerance**: Cluster resiliente

#### 🔧 Configurazione Test
- **Spring Boot 2.7.18** + **Java 21**
- **Hazelcast 5.1.7** con multicast discovery
- **H2 Database** in-memory per sviluppo
- **Spring Cache** integrato con Hazelcast

#### 🏗️ Architettura Testata
```
Istanza 8080 ──┐
               ├── Hazelcast Cluster (dev)
Istanza 8081 ──┘
  Cache distribuita condivisa
```

### Test API REST

#### Endpoint Testati
- ✅ `GET /actuator/health` - Health check
- ✅ `POST /user` - Creazione utente
- ✅ `GET /user/{id}` - Recupero utente con cache
- ✅ `GET /cache` - Test cache

#### Risultati API Test
```bash
# Health Check
GET /actuator/health
✅ Status: {"status":"UP"}

# Creazione Utente
POST /user
✅ Status: 201 Created
✅ Response: {"id":1,"name":"Test User"}

# Recupero da Cache
GET /user/1
✅ Status: 200 OK
✅ Cache Hit: Servito dalla cache distribuita
```

### Test Compilazione e Build

#### ✅ Build Success
```bash
mvn clean compile
✅ BUILD SUCCESS
✅ Total time: 3.778 s
```

#### 📦 Dipendenze Valide
- ✅ Spring Boot Starter Web
- ✅ Spring Boot Starter Data JPA
- ✅ Hazelcast
- ✅ H2 Database
- ✅ SpringDoc OpenAPI

### Test Logging e Monitoraggio

#### ✅ Logging Strutturato
- ✅ Log JSON configurato
- ✅ MDC con contesto pod/namespace
- ✅ Livelli appropriati (DEBUG/INFO/WARN)

#### ✅ Health Checks
- ✅ Spring Boot Actuator funzionante
- ✅ Endpoint `/actuator/health` disponibile
- ✅ Metriche Prometheus esposte

### Test Database

#### ✅ H2 Database (Sviluppo)
- ✅ In-memory funzionante
- ✅ Auto-create tabelle
- ✅ Console H2 accessibile su `/h2-console`
- ✅ JDBC URL: `jdbc:h2:mem:testdb`

#### ✅ PostgreSQL (Produzione)
- ✅ Configurazioni per staging/prod
- ✅ Connection pooling HikariCP
- ✅ JPA/Hibernate funzionanti

### Test Sicurezza e Configurazione

#### ✅ Configurazioni Ambiente
- ✅ `application-dev.yml` - H2 per sviluppo
- ✅ `application-staging.yml` - PostgreSQL staging
- ✅ `application-prod.yml` - PostgreSQL produzione

#### ✅ Hazelcast Configuration
- ✅ Multicast discovery per sviluppo
- ✅ Kubernetes discovery per produzione
- ✅ Cluster name configurato

## 📚 Documentazione Avanzata

## API Documentation

### Swagger UI
Una volta avviata l'applicazione, la documentazione interattiva API è disponibile su:
- **Locale**: http://localhost:8080/swagger-ui.html
- **OpenShift**: `https://<route-url>/swagger-ui.html`

### OpenAPI Specification
- **JSON**: `/v3/api-docs`
- **YAML**: `/v3/api-docs.yaml`

### Informazioni API Configurate
La documentazione OpenAPI include le seguenti informazioni:
- **Titolo**: Hazelcast Demo API
- **Versione**: 1.0.0
- **Descrizione**: API per dimostrazione cache distribuita con Hazelcast
- **Contatto**: Antonio Galluzzi (antonio.galluzzi91@gmail.com)
- **Licenza**: Apache 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
- **Server**:
  - **Sviluppo**: http://localhost:8080
  - **Produzione**: https://hazelcast-demo.apps.openshift.com

### Endpoint Documentati
- `GET /user/{id}` - Recupera utente con cache distribuita
- `POST /user` - Crea nuovo utente
- `GET /cache` - Test cache
- `GET /actuator/health` - Health check
- `GET /actuator/prometheus` - Metriche Prometheus</content>
<parameter name="filePath">c:\Users\anton\Downloads\hazelcast\README.md
