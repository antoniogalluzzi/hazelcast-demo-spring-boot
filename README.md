# Hazelcast Demo Project

Questo progetto dimostra l'uso di Spring Boot con Hazelcast per la cache distribuita e PostgreSQL come database su OpenShift.

## 👤 Autore

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

```bash
# Avvia l'applicazione con profilo dev (H2)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev

# Oppure con Maven
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
# Esegui setup PowerShell
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
