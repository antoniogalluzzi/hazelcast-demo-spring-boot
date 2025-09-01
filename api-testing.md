# API Testing Guide

Questa guida fornisce esempi completi per testare l'API del progetto Hazelcast Demo, che dimostra l'uso di cache distribuita con Spring Boot e Hazelcast.

## 📋 Panoramica API

### Endpoint Disponibili

| Metodo | Endpoint | Descrizione | Cache |
|--------|----------|-------------|-------|
| `GET` | `/user/{id}` | Recupera utente per ID | ✅ Distribuita |
| `POST` | `/user` | Crea nuovo utente | ❌ |
| `GET` | `/cache` | Stato cache distribuita | ✅ |
| `GET` | `/actuator/health` | Health check applicazione | ❌ |
| `GET` | `/actuator/prometheus` | Metriche Prometheus | ❌ |
| `GET` | `/h2-console` | Console H2 Database (solo dev) | ❌ |

### Modelli Dati

#### User Model
```json
{
  "id": 1,
  "name": "Mario Rossi",
  "createdAt": "2025-09-01T10:00:00Z"
}
```

#### Cache Info Model
```json
{
  "cacheName": "users",
  "size": 5,
  "hitRate": 0.95,
  "missRate": 0.05
}
```

## 🚀 Prerequisiti per i Test

### 1. Avvio Applicazione Locale

#### Per Linux/Mac (Bash)
```bash
# Build dell'applicazione
./mvnw clean package -DskipTests

# Avvio con profilo sviluppo (H2)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

#### Per Windows (PowerShell)
```powershell
# Build dell'applicazione
./mvnw.cmd clean package -DskipTests

# Avvio con profilo sviluppo (H2)
./mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=dev"
```

### 2. Verifica Avvio
```bash
# Health check
curl http://localhost:8080/actuator/health

# Risposta attesa:
# {"status":"UP"}
```

### 3. Accesso alla Console H2
- **URL**: http://localhost:8080/h2-console
- **JDBC URL**: jdbc:h2:mem:testdb
- **Username**: sa
- **Password**: *(vuoto)*

## 🖥️ Test con Swagger UI

### Accesso e Navigazione

1. **Avvio Applicazione**:
   - Assicurati che l'applicazione sia in esecuzione su `http://localhost:8080`

2. **Apertura Swagger UI**:
   - Naviga su: http://localhost:8080/swagger-ui.html
   - Oppure specifica JSON: http://localhost:8080/v3/api-docs

3. **Interfaccia Swagger**:
   - **Server**: Seleziona `http://localhost:8080` dall'elenco
   - **Authorize**: Non richiesto per questa demo
   - **Espandi endpoint**: Clicca sugli endpoint per vedere i dettagli

### Test Creazione Utente

1. **Espandi** `POST /user`
2. **Clicca** "Try it out"
3. **Inserisci JSON**:
   ```json
   {
     "name": "Mario Rossi"
   }
   ```
4. **Clicca** "Execute"
5. **Verifica Risposta**:
   - **Status**: 201 Created
   - **Response Body**:
     ```json
     {
       "id": 1,
       "name": "Mario Rossi",
       "createdAt": "2025-09-01T10:00:00.000+00:00"
     }
     ```

### Test Recupero Utente

1. **Espandi** `GET /user/{id}`
2. **Clicca** "Try it out"
3. **Inserisci ID**: `1`
4. **Clicca** "Execute"
5. **Verifica Risposta**:
   - **Status**: 200 OK
   - **Response Body**: Uguale alla creazione
   - **Cache Hit**: Dovrebbe essere servito dalla cache distribuita

### Test Stato Cache

1. **Espandi** `GET /cache`
2. **Clicca** "Try it out"
3. **Clicca** "Execute"
4. **Verifica Risposta**:
   ```json
   {
     "cacheName": "users",
     "size": 1,
     "hitRate": 1.0,
     "missRate": 0.0
   }
   ```


## 🐚 Test con cURL

### Preparazione Ambiente

#### Per Linux/Mac (Bash)
```bash
# Verifica che curl sia installato
curl --version

# Salva base URL in una variabile
BASE_URL="http://localhost:8080"
```

#### Per Windows (PowerShell)
```powershell
# Verifica che curl sia disponibile (PowerShell ha curl built-in)
curl --version

# Salva base URL in una variabile
$BASE_URL = "http://localhost:8080"
```

### Test Creazione Utente

#### Per Linux/Mac (Bash)
```bash
# Creazione utente semplice
curl -X POST $BASE_URL/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Mario Rossi"}'

# Creazione con output formattato
curl -X POST $BASE_URL/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Luigi Verdi"}' \
  | jq '.'

# Creazione multipla per test
for name in "Anna Bianchi" "Giuseppe Neri" "Francesca Blu"; do
  curl -X POST $BASE_URL/user \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$name\"}" \
    -s | jq '.name'
done
```

#### Per Windows (PowerShell)
```powershell
# Creazione utente semplice
curl -X POST $BASE_URL/user -H "Content-Type: application/json" -d '{"name": "Mario Rossi"}'

# Creazione con output formattato (richiede jq o parsing manuale)
curl -X POST $BASE_URL/user -H "Content-Type: application/json" -d '{"name": "Luigi Verdi"}'

# Creazione multipla per test
"Mario Rossi", "Luigi Verdi", "Anna Bianchi" | ForEach-Object {
  curl -X POST $BASE_URL/user -H "Content-Type: application/json" -d "{`"name`": `"$_`"}" -s
}
```

### Test Recupero Utente

#### Per Linux/Mac (Bash)
```bash
# Recupero utente specifico
curl -X GET $BASE_URL/user/1 | jq '.'

# Test cache hit (seconda chiamata dovrebbe essere più veloce)
time curl -X GET $BASE_URL/user/1 -s > /dev/null

# Recupero utente inesistente (dovrebbe restituire 404)
curl -X GET $BASE_URL/user/999

# Recupero con headers dettagliati
curl -X GET $BASE_URL/user/1 \
  -v \
  -H "Accept: application/json"
```

#### Per Windows (PowerShell)
```powershell
# Recupero utente specifico
curl -X GET $BASE_URL/user/1

# Test cache hit (misura tempo risposta)
Measure-Command { curl -X GET $BASE_URL/user/1 -s }

# Recupero utente inesistente
curl -X GET $BASE_URL/user/999

# Recupero con headers dettagliati
curl -X GET $BASE_URL/user/1 -v -H "Accept: application/json"
```

### Test Stato Cache

#### Per Linux/Mac (Bash)
```bash
# Stato cache corrente
curl -X GET $BASE_URL/cache | jq '.'

# Monitoraggio cache durante operazioni
curl -X POST $BASE_URL/user -H "Content-Type: application/json" -d '{"name": "Test User"}' -s > /dev/null
curl -X GET $BASE_URL/cache | jq '.'
```

#### Per Windows (PowerShell)
```powershell
# Stato cache corrente
curl -X GET $BASE_URL/cache

# Monitoraggio cache durante operazioni
curl -X POST $BASE_URL/user -H "Content-Type: application/json" -d '{"name": "Test User"}' -s | Out-Null
curl -X GET $BASE_URL/cache
```

### Test Health Check

#### Per Linux/Mac (Bash)
```bash
# Health check semplice
curl -X GET $BASE_URL/actuator/health | jq '.'

# Health check dettagliato
curl -X GET $BASE_URL/actuator/health \
  -H "Accept: application/json" \
  | jq '.'

# Health check con monitoraggio continuo
watch -n 5 'curl -s http://localhost:8080/actuator/health | jq .status'
```

#### Per Windows (PowerShell)
```powershell
# Health check semplice
curl -X GET $BASE_URL/actuator/health

# Health check dettagliato
curl -X GET $BASE_URL/actuator/health -H "Accept: application/json"

# Health check con monitoraggio continuo (simulato)
while ($true) {
  curl -X GET $BASE_URL/actuator/health -s
  Start-Sleep -Seconds 5
}
```

### Test Metriche Prometheus

#### Per Linux/Mac (Bash)
```bash
# Metriche complete
curl -X GET $BASE_URL/actuator/prometheus

# Metriche specifiche Hazelcast
curl -X GET $BASE_URL/actuator/prometheus | grep hazelcast

# Metriche HTTP
curl -X GET $BASE_URL/actuator/prometheus | grep http_server

# Metriche JVM
curl -X GET $BASE_URL/actuator/prometheus | grep jvm
```

#### Per Windows (PowerShell)
```powershell
# Metriche complete
curl -X GET $BASE_URL/actuator/prometheus

# Metriche specifiche Hazelcast
(Invoke-WebRequest -Uri $BASE_URL/actuator/prometheus).Content | Select-String 'hazelcast'

# Metriche HTTP
(Invoke-WebRequest -Uri $BASE_URL/actuator/prometheus).Content | Select-String 'http_server'

# Metriche JVM
(Invoke-WebRequest -Uri $BASE_URL/actuator/prometheus).Content | Select-String 'jvm'
```

## 📮 Test con Postman

### Importazione Specifica OpenAPI

1. **Esporta Specifica OpenAPI**:
   ```bash
   curl -X GET http://localhost:8080/v3/api-docs -o openapi-spec.json
   ```

2. **Importa in Postman**:
   - Apri Postman
   - Clicca "Import" in alto a sinistra
   - Seleziona "File"
   - Scegli `openapi-spec.json`
   - Clicca "Import"

3. **Configura Ambiente**:
   - Crea nuovo ambiente: "Hazelcast Demo Local"
   - Aggiungi variabili:
     ```
     baseUrl: http://localhost:8080
     userId: 1
     ```

### Collezione di Test Completa

```json
{
  "info": {
    "name": "Hazelcast Demo API - Test Suite",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "{{baseUrl}}/actuator/health",
          "host": ["{{baseUrl}}"],
          "path": ["actuator", "health"]
        },
        "description": "Verifica che l'applicazione sia in esecuzione"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "pm.test(\"Status code is 200\", function () {",
              "    pm.response.to.have.status(200);",
              "});",
              "",
              "pm.test(\"Response has status UP\", function () {",
              "    var jsonData = pm.response.json();",
              "    pm.expect(jsonData.status).to.eql(\"UP\");",
              "});"
            ]
          }
        }
      ]
    },
    {
      "name": "Create User",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\"name\": \"{{userName}}\"}"
        },
        "url": {
          "raw": "{{baseUrl}}/user",
          "host": ["{{baseUrl}}"],
          "path": ["user"]
        },
        "description": "Crea un nuovo utente"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "pm.test(\"Status code is 201\", function () {",
              "    pm.response.to.have.status(201);",
              "});",
              "",
              "pm.test(\"Response has user data\", function () {",
              "    var jsonData = pm.response.json();",
              "    pm.expect(jsonData).to.have.property('id');",
              "    pm.expect(jsonData).to.have.property('name');",
              "    pm.expect(jsonData.name).to.eql(pm.variables.get(\"userName\"));",
              "});",
              "",
              "pm.test(\"Set userId for next request\", function () {",
              "    var jsonData = pm.response.json();",
              "    pm.collectionVariables.set(\"userId\", jsonData.id);",
              "});"
            ]
          }
        }
      ]
    },
    {
      "name": "Get User",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "{{baseUrl}}/user/{{userId}}",
          "host": ["{{baseUrl}}"],
          "path": ["user", "{{userId}}"]
        },
        "description": "Recupera utente per ID (dalla cache)"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "pm.test(\"Status code is 200\", function () {",
              "    pm.response.to.have.status(200);",
              "});",
              "",
              "pm.test(\"Response matches expected user\", function () {",
              "    var jsonData = pm.response.json();",
              "    pm.expect(jsonData.id).to.eql(parseInt(pm.collectionVariables.get(\"userId\")));",
              "});"
            ]
          }
        }
      ]
    },
    {
      "name": "Get Cache Status",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "{{baseUrl}}/cache",
          "host": ["{{baseUrl}}"],
          "path": ["cache"]
        },
        "description": "Verifica stato cache distribuita"
      },
      "event": [
        {
          "listen": "test",
          "script": {
            "exec": [
              "pm.test(\"Status code is 200\", function () {",
              "    pm.response.to.have.status(200);",
              "});",
              "",
              "pm.test(\"Cache info is present\", function () {",
              "    var jsonData = pm.response.json();",
              "    pm.expect(jsonData).to.have.property('cacheName');",
              "    pm.expect(jsonData).to.have.property('size');",
              "});"
            ]
          }
        }
      ]
    }
  ],
  "variable": [
    {
      "key": "baseUrl",
      "value": "http://localhost:8080"
    },
    {
      "key": "userName",
      "value": "Test User"
    }
  ]
}
```

### Esecuzione Test Automatici

1. **Apri Runner Postman**:
   - Clicca "Runner" nella barra laterale

2. **Seleziona Collezione**:
   - Scegli "Hazelcast Demo API - Test Suite"

3. **Configura Esecuzione**:
   - **Iterations**: 3
   - **Delay**: 1000ms
   - **Data File**: (opzionale per test parametrizzati)

4. **Avvia Test**:
   - Clicca "Run Hazelcast Demo API"
   - Monitora risultati in tempo reale

## 🧪 Test di Validazione e Errori

### Test Dati di Input

#### Creazione Utente con Dati Validi
```bash
# Test con nome valido
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Mario Rossi"}' \
  -w "\nStatus: %{http_code}\n"

# Test con nome lungo
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Un nome molto lungo per testare la validazione dei dati di input"}' \
  -w "\nStatus: %{http_code}\n"
```

#### Test con Dati Non Validi
```bash
# Test con JSON malformato
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "invalidField": "value"}' \
  -w "\nStatus: %{http_code}\n"

# Test con nome vuoto
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": ""}' \
  -w "\nStatus: %{http_code}\n"

# Test senza Content-Type
curl -X POST http://localhost:8080/user \
  -d '{"name": "Test User"}' \
  -w "\nStatus: %{http_code}\n"
```

### Test Errori e Edge Cases

#### Utente Inesistente
```bash
# Test GET con ID non esistente
curl -X GET http://localhost:8080/user/999 \
  -w "\nStatus: %{http_code}\n"

# Risposta attesa: 404 Not Found
```

#### Richieste Malformate
```bash
# Test con metodo non supportato
curl -X PUT http://localhost:8080/user/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}' \
  -w "\nStatus: %{http_code}\n"

# Test con endpoint inesistente
curl -X GET http://localhost:8080/nonexistent \
  -w "\nStatus: %{http_code}\n"
```

#### Test Limiti
```bash
# Test con ID negativo
curl -X GET http://localhost:8080/user/-1 \
  -w "\nStatus: %{http_code}\n"

# Test con ID molto grande
curl -X GET http://localhost:8080/user/999999 \
  -w "\nStatus: %{http_code}\n"
```

## 🔄 Test Cache Distribuita

### Concetto di Cache Distribuita

La cache distribuita Hazelcast permette di:
- **Condividere dati** tra multiple istanze dell'applicazione
- **Migliorare performance** servendo dati dalla memoria
- **Scalare orizzontalmente** senza perdita di dati
- **Auto-rilevamento** dei membri del cluster

### Test Multi-Istanza

#### Avvio Multiple Istanze
```bash
# Istanza 1 (porta 8080)
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev -Dserver.port=8080

# Istanza 2 (porta 8081) - Terminale separato
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev -Dserver.port=8081
```

#### Test Sincronizzazione Cache
```bash
# Crea utente su istanza 1
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "User from Instance 1"}'

# Recupera utente da istanza 2 (dovrebbe essere in cache)
curl -X GET http://localhost:8081/user/1

# Verifica stato cache su entrambe le istanze
curl -X GET http://localhost:8080/cache
curl -X GET http://localhost:8081/cache
```

### Test Performance Cache

#### Misurazione Tempi di Risposta
```bash
# Prima chiamata (cache miss)
time curl -X GET http://localhost:8080/user/1 -s > /dev/null

# Seconda chiamata (cache hit - dovrebbe essere più veloce)
time curl -X GET http://localhost:8080/user/1 -s > /dev/null

# Confronto con chiamata al database diretto
time curl -X GET http://localhost:8080/user/999 -s > /dev/null
```

#### Monitoraggio Hit Rate
```bash
# Script per monitoraggio continuo
while true; do
  echo "$(date): $(curl -s http://localhost:8080/cache | jq '.hitRate')"
  sleep 5
done
```

## 🔧 Configurazione Ambiente di Test

Prima di eseguire test di performance e load, è necessario configurare gli strumenti appropriati. Questa sezione fornisce istruzioni dettagliate per l'installazione e configurazione.

### Installazione Strumenti di Base

#### Per Linux/Mac (Bash)

##### Apache Bench (ab)
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install apache2-utils

# CentOS/RHEL/Fedora
sudo yum install httpd-tools
# oppure
sudo dnf install httpd-tools

# macOS (con Homebrew)
brew install apachebench

# Verifica installazione
ab -V
```

##### jq (per parsing JSON)
```bash
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq

# Verifica installazione
jq --version
```

##### watch (per monitoraggio in tempo reale)
```bash
# Ubuntu/Debian (generalmente preinstallato)
which watch || sudo apt-get install procps

# CentOS/RHEL
sudo yum install procps-ng

# macOS (preinstallato)
which watch

# Verifica installazione
watch --version
```

##### curl avanzato (con supporto completo)
```bash
# Verifica versione corrente
curl --version

# Su macOS, curl è generalmente aggiornato
# Su Linux, potrebbe essere necessario aggiornare
```

#### Per Windows (PowerShell)

##### Apache Bench (ab)
```powershell
# Scarica Apache HTTP Server (include ab.exe)
# Vai su https://www.apachehaus.com/cgi-bin/download.plx
# Scarica Apache 2.4.x per Windows
# Estrai in C:\Apache24

# Aggiungi al PATH
$env:Path += ";C:\Apache24\bin"

# Verifica installazione
ab -V
```

##### jq (per parsing JSON)
```powershell
# Scarica jq da https://stedolan.github.io/jq/download/
# Oppure usa Chocolatey
choco install jq

# Verifica installazione
jq --version
```

##### curl (built-in in Windows 10+)
```powershell
# Verifica che curl sia disponibile
curl --version

# Se non presente, abilita Windows Subsystem for Linux
# Oppure scarica da https://curl.se/windows/
```

### Installazione JMeter

#### Per Linux/Mac (Bash)

##### Download e Installazione
```bash
# Scarica JMeter
JMETER_VERSION="5.6.2"
wget https://downloads.apache.org/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz

# Estrai
tar -xzf apache-jmeter-${JMETER_VERSION}.tgz

# Sposta in posizione desiderata
sudo mv apache-jmeter-${JMETER_VERSION} /opt/jmeter

# Crea link simbolico
sudo ln -sf /opt/jmeter/bin/jmeter /usr/local/bin/jmeter

# Verifica installazione
jmeter --version
```

##### Configurazione JAVA_HOME (se necessario)
```bash
# Verifica Java
java -version

# Imposta JAVA_HOME se non configurato
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
```

#### Per Windows (PowerShell)

##### Download e Installazione
```powershell
# Scarica JMeter
$JMETER_VERSION = "5.6.2"
$JMETER_URL = "https://downloads.apache.org/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.zip"
$JMETER_ZIP = "apache-jmeter-${JMETER_VERSION}.zip"

# Scarica
Invoke-WebRequest -Uri $JMETER_URL -OutFile $JMETER_ZIP

# Estrai
Expand-Archive -Path $JMETER_ZIP -DestinationPath "C:\JMeter"

# Aggiungi al PATH
$env:Path += ";C:\JMeter\apache-jmeter-${JMETER_VERSION}\bin"

# Verifica installazione
jmeter --version
```

##### Configurazione JAVA_HOME
```powershell
# Verifica Java
java -version

# Imposta JAVA_HOME se necessario
$env:JAVA_HOME = "C:\Program Files\Java\jdk-11"
$env:Path += ";$env:JAVA_HOME\bin"
```

### Preparazione File di Test

#### Creazione File JSON per Test
```bash
# Crea directory per file di test
mkdir -p test-files

# File per creazione utente
cat > test-files/create_user.json << 'EOF'
{"name": "Load Test User"}
EOF

# File per creazione utente con timestamp
cat > test-files/create_user_timestamp.json << 'EOF'
{"name": "Load Test User $(date +%s)"}
EOF

# File per test bulk creation
cat > test-files/bulk_users.json << 'EOF'
[
  {"name": "User 001"},
  {"name": "User 002"},
  {"name": "User 003"}
]
EOF
```

#### Per Windows (PowerShell)
```powershell
# Crea directory
New-Item -ItemType Directory -Path "test-files" -Force

# File per creazione utente
@'
{"name": "Load Test User"}
'@ | Out-File -FilePath "test-files\create_user.json" -Encoding UTF8

# File per creazione utente con timestamp
@'
{"name": "Load Test User $(Get-Date -Format 'yyyyMMddHHmmss')"}
'@ | Out-File -FilePath "test-files\create_user_timestamp.json" -Encoding UTF8
```

### Configurazione Ambiente di Test

#### Script di Setup Ambiente
```bash
#!/bin/bash
# setup-test-environment.sh

echo "🚀 Setup Ambiente di Test per Hazelcast Demo"
echo "==========================================="

# Verifica dipendenze
echo "Verifica dipendenze..."

command -v curl >/dev/null 2>&1 || { echo "❌ curl non trovato. Installalo."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ jq non trovato. Installalo."; exit 1; }
command -v ab >/dev/null 2>&1 || { echo "❌ Apache Bench non trovato. Installalo."; exit 1; }

echo "✅ Dipendenze verificate"

# Verifica applicazione in esecuzione
echo "Verifica applicazione..."
if curl -s http://localhost:8080/actuator/health | jq -e '.status == "UP"' >/dev/null 2>&1; then
    echo "✅ Applicazione in esecuzione"
else
    echo "❌ Applicazione non in esecuzione su localhost:8080"
    echo "Avvia con: ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev"
    exit 1
fi

# Prepara dati di test
echo "Preparazione dati di test..."
mkdir -p test-files

# Crea utenti di test
echo "Creazione utenti di test..."
for i in {1..10}; do
    curl -s -X POST http://localhost:8080/user \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"Test User $i\"}" >/dev/null
done

echo "✅ Creati 10 utenti di test"

# Verifica cache
CACHE_SIZE=$(curl -s http://localhost:8080/cache | jq -r '.size')
echo "✅ Cache contiene $CACHE_SIZE elementi"

echo "==========================================="
echo "🎉 Ambiente di test configurato con successo!"
echo ""
echo "Strumenti disponibili:"
echo "  - curl: $(curl --version | head -1)"
echo "  - jq: $(jq --version)"
echo "  - ab: $(ab -V | head -1)"
echo "  - JMeter: $(jmeter --version 2>/dev/null | head -1 || echo 'Non installato')"
```

#### Esecuzione Setup
```bash
# Rendi eseguibile
chmod +x setup-test-environment.sh

# Esegui setup
./setup-test-environment.sh
```

### Configurazione JMeter per Test Avanzati

#### Template Test Plan JMeter
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.2">
    <hashTree>
        <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Hazelcast Demo Load Test" enabled="true">
            <stringProp name="TestPlan.comments"></stringProp>
            <boolProp name="TestPlan.functional_mode">false</boolProp>
            <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
            <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
            <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
                <collectionProp name="Arguments.arguments">
                    <elementProp name="BASE_URL" elementType="Argument">
                        <stringProp name="Argument.name">BASE_URL</stringProp>
                        <stringProp name="Argument.value">http://localhost:8080</stringProp>
                        <stringProp name="Argument.metadata">=</stringProp>
                    </elementProp>
                </collectionProp>
            </elementProp>
            <stringProp name="TestPlan.user_define_classpath"></stringProp>
        </TestPlan>
        <hashTree>
            <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Load Test Group" enabled="true">
                <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
                <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlGui" testclass="LoopController" testname="Loop Controller" enabled="true">
                    <boolProp name="LoopController.continue_forever">false</boolProp>
                    <stringProp name="LoopController.loops">100</stringProp>
                </elementProp>
                <stringProp name="ThreadGroup.num_threads">10</stringProp>
                <stringProp name="ThreadGroup.ramp_time">30</stringProp>
                <longProp name="ThreadGroup.start_time">1</longProp>
                <longProp name="ThreadGroup.end_time">1</longProp>
                <boolProp name="ThreadGroup.scheduler">false</boolProp>
                <stringProp name="ThreadGroup.duration"></stringProp>
                <stringProp name="ThreadGroup.delay"></stringProp>
                <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
            </ThreadGroup>
            <hashTree>
                <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="GET /user/1" enabled="true">
                    <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
                        <collectionProp name="Arguments.arguments"/>
                    </elementProp>
                    <stringProp name="HTTPSampler.domain">${BASE_URL}</stringProp>
                    <stringProp name="HTTPSampler.port">8080</stringProp>
                    <stringProp name="HTTPSampler.protocol">http</stringProp>
                    <stringProp name="HTTPSampler.contentEncoding"></stringProp>
                    <stringProp name="HTTPSampler.path">/user/1</stringProp>
                    <stringProp name="HTTPSampler.method">GET</stringProp>
                    <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
                    <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
                    <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
                    <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
                    <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
                    <stringProp name="HTTPSampler.connect_timeout"></stringProp>
                    <stringProp name="HTTPSampler.response_timeout"></stringProp>
                </HTTPSamplerProxy>
                <hashTree/>
                <ResultCollector guiclass="ViewResultsFullVisualizer" testclass="ResultCollector" testname="View Results Tree" enabled="true">
                    <boolProp name="ResultCollector.error_logging">false</boolProp>
                    <objProp>
                        <name>saveConfig</name>
                        <value class="SampleSaveConfiguration">
                            <time>true</time>
                            <latency>true</latency>
                            <timestamp>true</timestamp>
                            <success>true</success>
                            <label>true</label>
                            <code>true</code>
                            <message>true</message>
                            <threadName>true</threadName>
                            <dataType>true</dataType>
                            <encoding>false</encoding>
                            <assertions>true</assertions>
                            <subresults>true</subresults>
                            <responseData>false</responseData>
                            <samplerData>false</samplerData>
                            <xml>false</xml>
                            <fieldNames>true</fieldNames>
                            <responseHeaders>false</responseHeaders>
                            <requestHeaders>false</requestHeaders>
                            <responseDataOnError>false</responseDataOnError>
                            <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
                            <assertionsResultsToSave>0</assertionsResultsToSave>
                            <bytes>true</bytes>
                            <sentBytes>true</sentBytes>
                            <url>true</url>
                            <threadCounts>true</threadCounts>
                            <idleTime>true</idleTime>
                            <connectTime>true</connectTime>
                        </value>
                    </objProp>
                    <stringProp name="filename"></stringProp>
                </ResultCollector>
                <hashTree/>
                <ResultCollector guiclass="SummaryReport" testclass="ResultCollector" testname="Summary Report" enabled="true">
                    <boolProp name="ResultCollector.error_logging">false</boolProp>
                    <objProp>
                        <name>saveConfig</name>
                        <value class="SampleSaveConfiguration">
                            <time>true</time>
                            <latency>true</latency>
                            <timestamp>true</timestamp>
                            <success>true</success>
                            <label>true</label>
                            <code>true</code>
                            <message>true</message>
                            <threadName>true</threadName>
                            <dataType>true</dataType>
                            <encoding>false</encoding>
                            <assertions>true</assertions>
                            <subresults>true</subresults>
                            <responseData>false</responseData>
                            <samplerData>false</samplerData>
                            <xml>false</xml>
                            <fieldNames>true</fieldNames>
                            <responseHeaders>false</responseHeaders>
                            <requestHeaders>false</requestHeaders>
                            <responseDataOnError>false</responseDataOnError>
                            <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
                            <assertionsResultsToSave>0</assertionsResultsToSave>
                            <bytes>true</bytes>
                            <sentBytes>true</sentBytes>
                            <url>true</url>
                            <threadCounts>true</threadCounts>
                            <idleTime>true</idleTime>
                            <connectTime>true</connectTime>
                        </value>
                    </objProp>
                    <stringProp name="filename"></stringProp>
                </ResultCollector>
                <hashTree/>
            </hashTree>
        </hashTree>
    </hashTree>
</jmeterTestPlan>
```

#### Salvataggio e Utilizzo Template JMeter
```bash
# Salva il template
cat > hazelcast-demo-test.jmx << 'EOF'
[contenuto XML sopra]
EOF

# Esegui test
jmeter -n -t hazelcast-demo-test.jmx -l results.jtl

# Genera report HTML
jmeter -g results.jtl -o html-report/
```

### Monitoraggio Sistema Durante Test

#### Script di Monitoraggio Risorse
```bash
#!/bin/bash
# monitor-resources.sh

echo "📊 Monitoraggio Risorse Sistema"
echo "==============================="

# Monitora CPU, Memoria, Disco
echo "Risorse Sistema:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memoria: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "Disco: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"

# Monitora processo Java
JAVA_PID=$(pgrep -f "spring-boot:run")
if [ ! -z "$JAVA_PID" ]; then
    echo ""
    echo "Processo Java (PID: $JAVA_PID):"
    ps -p $JAVA_PID -o pid,ppid,cmd,%cpu,%mem --no-headers
fi

# Monitora connessioni di rete
echo ""
echo "Connessioni di rete sulla porta 8080:"
netstat -tlnp 2>/dev/null | grep :8080 || ss -tlnp | grep :8080

# Monitora metriche applicazione
echo ""
echo "Metriche Applicazione:"
curl -s http://localhost:8080/actuator/health | jq '.status'
curl -s http://localhost:8080/cache | jq '{size: .size, hitRate: .hitRate}'
```

#### Per Windows (PowerShell)
```powershell
# Script di monitoraggio risorse
Write-Host "📊 Monitoraggio Risorse Sistema" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# CPU e Memoria
$cpu = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | Select Average
$mem = Get-WmiObject win32_operatingsystem | Select TotalVisibleMemorySize, FreePhysicalMemory
$memUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB, 2)
$memTotal = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)

Write-Host "CPU: $($cpu.Average)%"
Write-Host "Memoria: ${memUsed}MB / ${memTotal}MB"

# Processo Java
$javaProcess = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcess) {
    Write-Host ""
    Write-Host "Processo Java:"
    $javaProcess | Format-Table Id, CPU, WorkingSet -AutoSize
}

# Connessioni di rete (richiede admin)
Write-Host ""
Write-Host "Connessioni di rete (porta 8080):"
netstat -ano | findstr :8080
```

### Configurazione Ambiente Virtuale (Opzionale)

#### Per Test Isolati
```bash
# Crea ambiente virtuale con Docker
docker run --name hazelcast-test-env \
  -p 8080:8080 \
  -v $(pwd):/app \
  -w /app \
  openjdk:21-jdk \
  bash -c "
    apt-get update && \
    apt-get install -y curl jq apache2-utils && \
    ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
  "
```

Ora che hai configurato completamente l'ambiente di test, puoi procedere con i test di performance e load utilizzando gli strumenti installati.

### Test con Apache Bench

#### Installazione Apache Bench
```bash
# Ubuntu/Debian
sudo apt-get install apache2-utils

# macOS
brew install apachebench

# CentOS/RHEL
sudo yum install httpd-tools
```

#### Test Load Semplice
```bash
# Test lettura cache (1000 richieste, 10 concorrenti)
ab -n 1000 -c 10 http://localhost:8080/user/1

# Test creazione utenti (100 richieste, 5 concorrenti)
ab -n 100 -c 5 -p create_user.json -T application/json http://localhost:8080/user

# File create_user.json
echo '{"name": "Load Test User"}' > create_user.json
```

#### Test Cache Performance
```bash
# Confronto cache hit vs miss
ab -n 500 -c 5 http://localhost:8080/user/1      # Cache hit
ab -n 500 -c 5 http://localhost:8080/user/999    # Cache miss (se utente non esiste)
```

### Test con JMeter

#### Installazione JMeter
```bash
# Download e installazione
wget https://downloads.apache.org/jmeter/binaries/apache-jmeter-5.6.2.tgz
tar -xzf apache-jmeter-5.6.2.tgz
cd apache-jmeter-5.6.2/bin
./jmeter
```

#### Configurazione Test Plan JMeter

1. **Crea Thread Group**:
   - **Number of Threads**: 50
   - **Ramp-up period**: 10 secondi
   - **Loop Count**: Forever

2. **Aggiungi HTTP Request Defaults**:
   - **Server Name**: localhost
   - **Port Number**: 8080
   - **Protocol**: http

3. **Aggiungi HTTP Request per GET /user/1**:
   - **Method**: GET
   - **Path**: /user/1

4. **Aggiungi HTTP Request per POST /user**:
   - **Method**: POST
   - **Path**: /user
   - **Body Data**: `{"name": "JMeter Test User ${__threadNum}"}`

5. **Aggiungi Listeners**:
   - **View Results Tree**
   - **Summary Report**
   - **Response Time Graph**

#### Esecuzione Test JMeter
```bash
# Esegui test da command line
./jmeter -n -t hazelcast-demo-test.jmx -l results.jtl

# Genera report HTML
./jmeter -g results.jtl -o report/
```

## 📈 Monitoraggio e Metriche

### Metriche Disponibili

#### Metriche HTTP
```bash
# Richieste totali
curl -s http://localhost:8080/actuator/prometheus | grep http_server_requests

# Tempi di risposta
curl -s http://localhost:8080/actuator/prometheus | grep http_server_request_duration

# Codici di stato
curl -s http://localhost:8080/actuator/prometheus | grep http_server_responses
```

#### Metriche Hazelcast
```bash
# Statistiche cache
curl -s http://localhost:8080/actuator/prometheus | grep hazelcast

# Membri cluster
curl -s http://localhost:8080/actuator/prometheus | grep hazelcast_cluster
```

#### Metriche JVM
```bash
# Utilizzo memoria
curl -s http://localhost:8080/actuator/prometheus | grep jvm_memory

# Garbage collection
curl -s http://localhost:8080/actuator/prometheus | grep jvm_gc

# Thread attivi
curl -s http://localhost:8080/actuator/prometheus | grep jvm_threads
```

### Dashboard Grafana

#### Configurazione Sorgente Dati
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'hazelcast-demo'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/actuator/prometheus'
```

#### Query Grafana Esempi
```promql
# Throughput HTTP
rate(http_server_requests_total[5m])

# Latenza p95
histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))

# Hit rate cache
hazelcast_cache_hit_rate

# Utilizzo memoria
jvm_memory_used_bytes / jvm_memory_max_bytes
```

## 🔒 Test di Sicurezza

### Test Autenticazione
```bash
# Test endpoint senza autenticazione (atteso: 200 per demo)
curl -X GET http://localhost:8080/user/1 \
  -w "\nStatus: %{http_code}\n"

# Test con header Authorization (se implementato)
curl -X GET http://localhost:8080/user/1 \
  -H "Authorization: Bearer fake-token" \
  -w "\nStatus: %{http_code}\n"
```

### Test Validazione Input
```bash
# Test SQL injection attempt
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Test'; DROP TABLE users; --"}' \
  -w "\nStatus: %{http_code}\n"

# Test XSS attempt
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "<script>alert(\"XSS\")</script>"}' \
  -w "\nStatus: %{http_code}\n"
```

### Test Rate Limiting
```bash
# Test burst requests
for i in {1..20}; do
  curl -X GET http://localhost:8080/user/1 -s -w "%{http_code} " &
done
wait
echo "Test rate limiting completato"
```

## 🤖 Automazione Test

### Script Bash per Test Completi
```bash
#!/bin/bash
# test-suite.sh

BASE_URL="http://localhost:8080"
TEST_USER="Test Automation User"

echo "🚀 Avvio Test Suite Hazelcast Demo"
echo "==================================="

# Test 1: Health Check
echo "1. Health Check..."
if curl -s $BASE_URL/actuator/health | grep -q '"status":"UP"'; then
    echo "✅ Health Check PASSED"
else
    echo "❌ Health Check FAILED"
    exit 1
fi

# Test 2: Creazione Utente
echo "2. Creazione Utente..."
USER_RESPONSE=$(curl -s -X POST $BASE_URL/user \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TEST_USER\"}")

USER_ID=$(echo $USER_RESPONSE | jq -r '.id')
if [ "$USER_ID" != "null" ] && [ "$USER_ID" != "" ]; then
    echo "✅ Creazione Utente PASSED (ID: $USER_ID)"
else
    echo "❌ Creazione Utente FAILED"
    exit 1
fi

# Test 3: Recupero Utente
echo "3. Recupero Utente..."
GET_RESPONSE=$(curl -s -X GET $BASE_URL/user/$USER_ID)
RETRIEVED_NAME=$(echo $GET_RESPONSE | jq -r '.name')
if [ "$RETRIEVED_NAME" = "$TEST_USER" ]; then
    echo "✅ Recupero Utente PASSED"
else
    echo "❌ Recupero Utente FAILED"
    exit 1
fi

# Test 4: Stato Cache
echo "4. Stato Cache..."
CACHE_RESPONSE=$(curl -s -X GET $BASE_URL/cache)
CACHE_SIZE=$(echo $CACHE_RESPONSE | jq -r '.size')
if [ "$CACHE_SIZE" -gt 0 ]; then
    echo "✅ Stato Cache PASSED (Size: $CACHE_SIZE)"
else
    echo "❌ Stato Cache FAILED"
fi

echo "==================================="
echo "🎉 Tutti i test completati con successo!"
```

### Esecuzione Script Automatizzato
```bash
# Rendi eseguibile e avvia
chmod +x test-suite.sh
./test-suite.sh
```

## 📋 Checklist Test Completa

### Test Funzionali
- [ ] Creazione utente valida
- [ ] Recupero utente esistente
- [ ] Recupero utente inesistente (404)
- [ ] Stato cache aggiornato
- [ ] Health check positivo

### Test Prestazionali
- [ ] Cache hit più veloce di cache miss
- [ ] Throughput > 500 req/sec
- [ ] Latenza < 50ms per cache hit
- [ ] Memoria < 512MB per pod

### Test di Robustezza
- [ ] Gestione errori input malformato
- [ ] Rate limiting (se implementato)
- [ ] Connessione database interrotta
- [ ] Cluster Hazelcast ripartito

### Test di Sicurezza
- [ ] Validazione input
- [ ] Protezione SQL injection
- [ ] Headers sicuri
- [ ] Logging sicuro

## 🔧 Troubleshooting

### Problemi Comuni

#### Applicazione non si avvia
```bash
# Verifica porte occupate
netstat -tulpn | grep :8080

# Verifica Java installato
java -version

# Verifica Maven
./mvnw --version
```

#### Cache non funziona
```bash
# Verifica configurazione Hazelcast
curl -X GET http://localhost:8080/cache

# Controlla log per errori Hazelcast
tail -f logs/spring.log | grep hazelcast
```

#### Database non accessibile
```bash
# Verifica connessione H2
curl -X GET http://localhost:8080/h2-console

# Controlla configurazione database
cat src/main/resources/application-dev.yml
```

Questo conclude la guida completa per il testing dell'API Hazelcast Demo. La guida copre tutti gli aspetti importanti: test funzionali, prestazionali, di sicurezza e automazione.
