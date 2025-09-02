# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2025-09-02

### 🚀 Major - Nuova Architettura Script Modulari

#### Added
- **Sistema Script Completamente Rinnovato**: Architettura modulare che sostituisce i vecchi script monolitici
  - `scripts/README.md` - Documentazione completa dei nuovi script (800+ righe)
  - `scripts/utilities/common-functions.ps1` - Libreria funzioni condivise (800+ righe)
    - Sistema logging avanzato con colori (Write-Info, Write-Success, Write-Error)
    - Retry logic con backoff exponential per operazioni critiche
    - Checkpoint/recovery per resume operazioni interrotte
    - Utilità progetto (Get-ProjectRoot, Get-GitBranch, Test-ApplicationHealth)
  - `scripts/utilities/environment-check.ps1` - Verifica prerequisiti completa
    - Check versioni Java, Maven, Docker, Git, OpenShift CLI
    - Controllo risorse sistema (CPU, memoria, disco)
    - Test connectivity e network configuration

#### Added - Script di Setup
- **`scripts/setup/setup-dev-environment.ps1`** - Setup sviluppo locale automatizzato
  - Verifica e installazione tool mancanti
  - Configurazione ambiente con variables e profiles
  - Build iniziale con Maven clean install
  - Validazione setup con health check e API testing
- **`scripts/setup/setup-openshift-local.ps1`** - Setup OpenShift Local completo (sostituisce il vecchio)
  - Installazione automatica Red Hat OpenShift Local (CRC)
  - Gestione completa cluster (start, stop, resource allocation)
  - Deploy automatico PostgreSQL e application
  - Configurazione networking e routes

#### Added - Development Tools  
- **`scripts/development/cluster-manager.ps1`** - Gestione cluster Hazelcast avanzata (800+ righe)
  - Startup multi-istanza configurabile (2-10 nodi)
  - Background job management con PowerShell jobs
  - Health monitoring e status reporting real-time
  - Test distribuzione cache e sincronizzazione dati
  - Graceful shutdown con cleanup automatico
- **`scripts/development/test-api-endpoints.ps1`** - Testing API completo (900+ righe)
  - Test suite comprehensive (health, CRUD, cache, docs, error handling)
  - Performance testing con metriche latency e throughput
  - Stress testing con concurrent requests e load analysis
  - Export risultati in formato JSON per CI/CD integration

#### Added - Build e Deploy
- **`scripts/build/build-and-deploy.ps1`** - Automazione build e deploy completa
  - Multi-environment support (dev, staging, prod, openshift-local, cloud)
  - Multi-target deployment (local, docker, openshift, kubernetes)
  - Container image management (build, tag, push, registry)
  - Deployment orchestration con health checks

### 🗑️ Removed - Cleanup Architetturale
- **Eliminati Script Monolitici**: Rimossi i vecchi script da 2000+ righe totali
  - ❌ `setup-openshift-local.ps1` (1294 righe) - Sostituito da versione modulare
  - ❌ `start-local-dev.ps1` (871 righe) - Sostituito da cluster-manager.ps1 e setup-dev-environment.ps1

### 📚 Changed - Documentazione Aggiornata
- **`README.md`** - Aggiornato con nuova struttura script e quick commands
- **`DOCUMENTATION.md`** - Nuova sezione dedicata "Script di Automazione" con guida completa
  - Documentazione dettagliata di ogni script con esempi
  - Sezione caratteristiche avanzate (robustezza, flessibilità, performance)
  - Integration nella sezione Testing con riferimenti ai nuovi script automatizzati

### ✨ Benefits della Nuova Architettura
- **Modularità**: Funzioni comuni condivise, specializzazione per funzionalità
- **Riusabilità**: Libreria utilities utilizzabile da tutti gli script
- **Robustezza**: Retry logic, checkpoint/recovery, gestione errori avanzata
- **Flessibilità**: Multi-ambiente, multi-target, parametrizzazione completa
- **Manutenibilità**: Codice organizzato, documentato, facile da estendere
- **Performance**: Background jobs, operazioni parallele, caching ottimizzato

## [Unreleased]

### Added
- **Configurazione Multi-Ambiente Completa**: Sistema completo di configurazioni per ogni ambiente
  - `application.yml` - Configurazioni base comuni
  - `application-dev.yml` - Sviluppo locale (H2 + multicast)
  - `application-staging.yml` - Staging (PostgreSQL + TCP/IP)
  - `application-openshift-local.yml` - OpenShift Local (PostgreSQL + Kubernetes discovery)
  - `application-cloud.yml` - Cloud deployment (PostgreSQL + TCP/IP)
  - `application-prod.yml` - Produzione (PostgreSQL + TCP/IP)

- **Configurazione Hazelcast Java-based**: Migrazione da XML a configurazione Java per l'ambiente dev
  - `HazelcastDevConfig.java` - Configurazione programmatica per sviluppo
  - Multicast discovery per l'ambiente locale
  - Conditional activation basata su profile Spring
  - Code più maintainabile e type-safe

- **VS Code Integration Avanzata**: Configurazioni ottimizzate per lo sviluppo
  - Task Maven Wrapper configurati (`compile`, `clean compile`, `test`, `start dev`)
  - Settings Java ottimizzati per null analysis
  - Problem matcher configurati per errori di compilazione

- **Script PowerShell Professionali**: Automazione completa per Windows
  - `start-local-dev.ps1` - Avvio sviluppo con opzioni (clean, test, debug)
  - `setup-openshift-local.ps1` - Setup completo OpenShift Local
  - Gestione errori avanzata e output colorato
  - Supporto modalità debug (porta 5005)

### Changed
- **Struttura Progetto Drasticamente Semplificata**: Pulizia completa file inutili
  - **-67% file nella root** - Da 15+ a 5 file essenziali
  - **Zero duplicati** - Rimossi script Linux ridondanti
  - **Zero conflitti configurazione** - Sostituito `application.properties` con YAML
  - **Build pulito** - Rimossi archivi Maven embedded e JAR standalone

- **Configurazioni Unificate**: Migrazione completa a YAML per consistenza
  - Eliminato `application.properties` che causava conflitti
  - Configurazioni base in `application.yml`
  - Override specifici per ambiente nei file dedicati
  - Hazelcast XML generico reso sicuro (discovery disabilitato di default)

- **GitIgnore Intelligente**: Ottimizzazione completa delle regole di esclusione
  - **VS Code selettivo** - Mantiene configurazioni utili, esclude file user-specific
  - **Support completo IDE** - Eclipse, IntelliJ, NetBeans, VS Code
  - **Frontend ready** - Support per `node_modules` e file di ambiente
  - **Organizzato per categoria** - Facile da leggere e mantenere

### Removed
- **File Duplicati e Obsoleti**:
  - ❌ `start-local-dev.sh`, `setup-openshift-local.sh` (duplicati Linux)
  - ❌ `quick-test-commands.sh` (non necessario per dev locale)
  - ❌ `.github/copilot-instructions.md` (file setup temporaneo)
  - ❌ `application.properties` (sostituito da YAML)
  - ❌ `hazelcast-dev.xml` (sostituito da configurazione Java)

- **Archivi e File Temporanei**:
  - ❌ `hazelcast-demo.zip`, `maven.zip` (backup inutili)
  - ❌ `maven/` (cartella Maven embedded)
  - ❌ `h2.jar` (JAR standalone, gestito da Maven)
  - ❌ `testdb.mv.db`, `testdb.trace.db` (database temporanei)
  - ❌ `target/` (output build, si rigenera)

### Fixed
- **Conflitti di Configurazione**: Risolti conflitti tra file properties e YAML
- **Build Consistency**: Maven Wrapper utilizzato ovunque invece di Maven locale
- **Environment Isolation**: Ogni ambiente ha configurazioni dedicate senza overlap
- **Code Organization**: Configurazione Hazelcast refactoring per chiarezza e maintainability

### Performance
- **Startup più veloce**: Eliminati conflitti di configurazione
- **Build ottimizzato**: Rimossi file inutili che rallentavano la compilazione
- **Cache efficiente**: Configurazione Hazelcast environment-specific

### Documentation
- **Documentazione Unificata Completa**: Creato DOCUMENTATION.md unico e completo
  - Consolidate tutte le guide in un singolo file navigabile
  - Struttura progressiva: Quick Start → Architettura → Deployment → Testing
  - Sezioni specializzate per ogni ruolo (Developer, DevOps, Tester)
  - API Reference completa con esempi pratici
  - Troubleshooting avanzato con soluzioni step-by-step

- **README Semplificato**: Nuovo README.md focalizzato su quick start
  - Quick start in 30 secondi
  - Demo live con esempi copy-paste
  - Setup rapido per ruolo (Developer/DevOps/Tester)
  - Link diretto alla documentazione completa

- **Configurazione DNS per OpenShift Local**: Sezione completa aggiunta alla guida deployment
  - Guida passo-passo per configurazione file hosts
  - Troubleshooting DNS comune con soluzioni
  - Script PowerShell per automazione configurazione DNS
  - Test di verifica DNS e connettività TCP
  - Gestione IP dinamici CRC dopo riavvio

- **Documentazione Consolidata**: Riorganizzazione completa della documentazione
  - Eliminazione file ridondante `openshift-local-guide.md`
  - Creazione `DOCUMENTATION_ANALYSIS.md` per analisi struttura
  - Creazione `DOCUMENTATION_UPDATE_SUMMARY.md` per riepilogo modifiche
  - Aggiornamento riferimenti incrociati tra documenti
  - Navigazione ottimizzata dal README

### Changed
- **Struttura Documentazione**: Consolidamento da 2 guide sovrapposte a 1 guida principale
  - OPENSHIFT_DEPLOYMENT_GUIDE.md ora contiene tutto il necessario
  - Rimossi collegamenti rotti e riferimenti obsoleti
  - Migliorata navigazione gerarchica (README → Guide Specializzate)

### Fixed
- **Riferimenti Documentazione**: Corretti tutti i link e riferimenti dopo consolidamento
  - Aggiornato OPENSHIFT_DEPLOYMENT_GUIDE.md con note integrative
  - Rimosso riferimento a `openshift-local-guide.md` dal README
  - Aggiornati riferimenti in DOCUMENTATION_UPDATE_SUMMARY.md

### Documentation
- **Analisi Documentazione**: Documento completo dell'analisi struttura e raccomandazioni
  - Confronto tra struttura precedente e ottimale
  - Piano d'azione per consolidamento
  - Risultati ottenuti dal refactoring documentazione

## [1.1.0] - 2025-09-01

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-09-01

### Added
- **Deployment OpenShift Local Completo**:
  - Guida deployment step-by-step per principianti
  - Setup automatico con script PowerShell/Bash
  - Configurazione cluster Hazelcast distribuito (2 membri)
  - RBAC completo con service account e role binding
  - Route esposte per accesso esterno
  - Troubleshooting avanzato con soluzioni comuni

- **Sistema di Testing Avanzato**:
  - Test cache distribuita multi-istanza verificati
  - Test API REST completi con cURL e Postman
  - Test performance con Apache Bench e JMeter
  - Test di sicurezza e validazione input
  - Automazione test con script completi

- **Documentazione Cross-Platform**:
  - Comandi separati per Windows (PowerShell) e Linux/Mac (Bash)
  - Setup OpenShift Local per entrambi i sistemi operativi
  - Configurazioni ambiente unificate
  - Troubleshooting specifico per piattaforma

### Changed
- **Deployment Strategy**: Ottimizzato per OpenShift Local
  - Java 17 invece di 21 per compatibilità CRC
  - Configurazione Hazelcast Kubernetes discovery
  - Service account con permessi minimi necessari
  - Health checks e readiness probes

- **Documentazione Strutturata**: Riorganizzata documentazione per chiarezza
  - README.md aggiornato con sezione monitoraggio
  - Guide specializzate separate per argomento
  - Riferimenti incrociati tra documenti
  - Indice navigabile migliorato

### Fixed
- **Configurazioni Ambiente**: Allineate versioni Java (17) tra sviluppo e produzione
- **Dipendenze Maven**: Risolte incompatibilità SpringDoc OpenAPI
- **Configurazioni Hazelcast**: Corretta discovery per ambiente Kubernetes
- **Script Automazione**: Migliorata gestione errori e logging colorato

### Performance
- **Cache Distribuita**: Cluster Hazelcast 2+ membri funzionante
- **Database Connection Pool**: HikariCP ottimizzato con 10 connessioni min/max
- **JVM Tuning**: Configurazioni garbage collection ottimizzate

## [Unreleased]

### Fixed
- **POM.xml Formatting**: Corrected XML declaration and structure in `pom.xml` to resolve parsing errors and ensure proper Maven validation.

## [0.1.0] - 2025-09-01

### Added
- Initial Spring Boot 2.7.18 project setup with Java 21
- Hazelcast 5.1.7 distributed caching integration
- Spring Data JPA with User entity and repository
- REST API endpoints for user management with caching
- Micrometer metrics: registrazione e integrazione con sistemi esterni è fuori dal scope del repository
- Structured logging with Logstash Logback Encoder
- SpringDoc OpenAPI documentation
- GitHub repository setup and initial commit
- Basic project structure and configuration files

### Infrastructure
- Maven build configuration
- Application properties for different environments
- Hazelcast XML configuration
- Logback configuration for JSON logging
- Git initialization and remote repository setup

---

## 📝 Informazioni sull'Autore

**Antonio Galluzzi**
- **GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)
- **Email**: antonio.galluzzi91@gmail.com
- **Progetto**: [hazelcast-demo-spring-boot](https://github.com/antoniogalluzzi/hazelcast-demo-spring-boot)

Questo progetto è stato creato e mantenuto da Antonio Galluzzi come dimostrazione dell'integrazione tra Spring Boot e Hazelcast per la cache distribuita.
