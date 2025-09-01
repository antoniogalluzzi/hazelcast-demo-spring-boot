# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
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

### Changed
- **Struttura Documentazione Drasticamente Semplificata**: Da 11 file a 3 file
  - ✅ **README.md** - Quick start e overview (era 512 righe, ora 145 righe)
  - ✅ **DOCUMENTATION.md** - Guida completa unificata (tutto in uno)  
  - ✅ **CHANGELOG.md** - Registro modifiche
  - ❌ Rimossi 8 file ridondanti (api-testing.md, cloud-deployment.md, etc.)

### Fixed
- **Eliminata Frammentazione**: Non più ricerca attraverso file multipli
- **Navigazione Semplificata**: Tutto accessibile da README → DOCUMENTATION
- **Manutenzione Ridotta**: Un solo file da aggiornare per guide tecniche
- **User Experience**: Percorso lineare e intuitivo per ogni tipo di utente

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
