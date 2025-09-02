# �️ Script di Automazione - Architettura Modulare

> **Sistema Completo** di automazione per sviluppo, testing e deployment

**📅 Ultimo aggiornamento**: 2 Settembre 2025  
**🔧 Versione Scripts**: 2.0.0  
**✅ Status**: Error-Free, Production Ready

---

## � Panoramica

Questa directory contiene un **sistema modulare avanzato** di script PowerShell per automatizzare completamente il ciclo di sviluppo dell'applicazione Hazelcast Demo.

### 🎯 Caratteristiche Principali

- ✅ **Architettura Modulare**: Funzioni riutilizzabili, no duplicazioni
- ✅ **Error-Free**: Tutti gli script passano l'analisi statica PowerShell  
- ✅ **Robust Error Handling**: Retry logic, recovery, graceful failures
- ✅ **Logging Avanzato**: Multi-level, colorato, con timestamp
- ✅ **Cross-Environment**: Supporto dev, staging, prod, cloud
- ✅ **Documentazione Inline**: Help completo per ogni funzione

### 📊 Statistiche

| Categoria | Script | Righe Totali | Funzionalità |
|-----------|--------|--------------|--------------|
| **Utilities** | 2 | 1000+ | Base condivise |
| **Setup** | 2 | 800+ | Configurazione ambienti |
| **Development** | 2 | 1700+ | Testing e cluster mgmt |
| **Build** | 1 | 400+ | Deploy automatizzato |
| **TOTALE** | **7** | **3900+** | **Sistema completo** |

---

## 🗂️ Struttura Directory

```
scripts/
├── 📖 README.md                          # ← Questo file
├── utilities/                            # 🔧 FUNZIONI CONDIVISE
│   ├── common-functions.ps1              # Core library (810+ righe)
│   └── environment-check.ps1             # Prerequisites check
├── setup/                                # 🚀 CONFIGURAZIONE
│   ├── setup-dev-environment.ps1         # Setup sviluppo locale
│   └── setup-openshift-local.ps1         # OpenShift deployment
├── development/                          # 💻 STRUMENTI SVILUPPO
│   ├── cluster-manager.ps1               # Gestione cluster (800+ righe)
│   └── test-api-endpoints.ps1            # Testing suite (900+ righe)  
└── build/                                # 🏗️ BUILD & DEPLOY
    └── build-and-deploy.ps1              # Pipeline completa
```

---

## ⚡ Quick Start Guide

### 1. Setup Sviluppo (5 minuti)
```powershell
# Clone repository
git clone https://github.com/antoniogalluzzi/hazelcast-demo-spring-boot.git
cd hazelcast-demo-spring-boot

# Setup automatico ambiente
.\scripts\setup\setup-dev-environment.ps1

# Test API completo
.\scripts\development\test-api-endpoints.ps1 -TestLevel comprehensive
```

### 2. Cluster Multi-Istanza (3 minuti)
```powershell  
# Avvia cluster 3 nodi
.\scripts\development\cluster-manager.ps1 -Action start-cluster -Instances 3

# Verifica cluster formato
.\scripts\development\cluster-manager.ps1 -Action status

# Test cache distribuita
.\scripts\development\cluster-manager.ps1 -Action test-cache-sync
```

### 3. Deploy OpenShift (10 minuti)
```powershell
# Setup completo OpenShift Local
.\scripts\setup\setup-openshift-local.ps1 -Action all

# App disponibile su: https://hazelcast-demo-hazelcast-demo.apps-crc.testing
```

---

## 📚 Documentazione Completa

Per documentazione dettagliata di ogni script, parametri, esempi d'uso e troubleshooting:

**👉 [DOCUMENTATION.md](../DOCUMENTATION.md) - Sezione Script di Automazione**

---

**Happy Automating!** 🚀
.\scripts\development\start-local-dev.ps1

# Test API
.\scripts\testing\validate-deployment.ps1 -Environment local
```

### OpenShift Local (15 minuti) 
```powershell
# Setup completo OpenShift
.\scripts\setup\setup-openshift-local.ps1 -Command deploy

# Test completo
.\scripts\testing\validate-deployment.ps1 -Environment openshift-local
```

### Cloud Deployment (30 minuti)
```powershell
# AWS
.\scripts\setup\setup-cloud-aws.ps1 -ClusterName hazelcast-demo

# Azure  
.\scripts\setup\setup-cloud-azure.ps1 -ResourceGroup hazelcast-rg

# GCP
.\scripts\setup\setup-cloud-gcp.ps1 -Project hazelcast-project
```

## 📋 Script per Categoria

### 🏗️ Setup & Configuration
- **setup-dev-environment.ps1**: Configura ambiente sviluppo locale con H2
- **setup-openshift-local.ps1**: Deploy completo su OpenShift Local  
- **setup-cloud-*.ps1**: Setup specifici per cloud provider

### 🚀 Development & Testing
- **start-local-dev.ps1**: Gestione sviluppo locale multi-istanza
- **cluster-manager.ps1**: Gestione cluster Hazelcast locale
- **test-api-endpoints.ps1**: Test completi API REST

### 📦 Build & Deploy
- **build-application.ps1**: Build Maven con profili
- **build-docker-image.ps1**: Creazione immagini Docker
- **deploy-application.ps1**: Deploy multi-ambiente

### 🧪 Testing & Validation
- **run-*-tests.ps1**: Suite completa di test
- **validate-deployment.ps1**: Validazione post-deploy
- **performance-test.ps1**: Test performance e stress

### 🔧 Maintenance & Monitoring
- **cleanup-environment.ps1**: Pulizia selettiva ambienti
- **monitor-application.ps1**: Monitoring continuo
- **troubleshoot-issues.ps1**: Diagnostica problemi

### 🛠️ Utilities
- **common-functions.ps1**: Libreria funzioni comuni
- **environment-check.ps1**: Verifica prerequisiti
- **health-checker.ps1**: Health check avanzato

## 🎯 Utilizzo per Ruolo

### 👨‍💻 Sviluppatore
```powershell
# Setup rapido
.\scripts\setup\setup-dev-environment.ps1

# Sviluppo con cluster
.\scripts\development\cluster-manager.ps1 -Action start -Instances 3

# Test durante sviluppo
.\scripts\testing\run-unit-tests.ps1
```

### 🚀 DevOps Engineer
```powershell
# Deploy OpenShift
.\scripts\setup\setup-openshift-local.ps1 -Command release

# Deploy cloud
.\scripts\setup\setup-cloud-aws.ps1 -Environment production

# Monitoring
.\scripts\maintenance\monitor-application.ps1 -Continuous
```

### 🧪 QA Tester
```powershell
# Test completi
.\scripts\testing\run-integration-tests.ps1

# Test performance
.\scripts\testing\run-performance-tests.ps1 -LoadLevel high

# Validazione deployment
.\scripts\testing\validate-deployment.ps1 -Environment staging
```

### 🔧 System Administrator
```powershell
# Health check
.\scripts\utilities\health-checker.ps1 -Detailed

# Troubleshooting
.\scripts\maintenance\troubleshoot-issues.ps1 -Component hazelcast

# Backup
.\scripts\maintenance\backup-database.ps1 -Environment production
```

## 🌟 Caratteristiche Avanzate

### ⚡ Execution Intelligence
- **Auto-Detection**: Rileva ambiente esistente e configurazioni
- **Smart Recovery**: Riprende operazioni interrotte
- **Dependency Check**: Verifica prerequisiti automaticamente
- **Error Handling**: Gestione errori robusta con recovery

### 🛡️ Safety Features
- **Dry-Run Mode**: Anteprima operazioni senza esecuzione
- **Backup Before Change**: Backup automatico prima modifiche
- **Rollback Support**: Rollback automatico in caso di errore
- **Environment Isolation**: Isolamento completo tra ambienti

### 📊 Monitoring & Reporting
- **Real-time Progress**: Progress bar e status in tempo reale
- **Detailed Logging**: Log strutturati con livelli
- **Performance Metrics**: Metriche tempo e risorse
- **Success Reports**: Report dettagliati successo/fallimento

### 🔄 CI/CD Integration
- **Pipeline Ready**: Integrazione diretta pipeline CI/CD
- **Environment Variables**: Configurazione via variabili ambiente
- **Exit Codes**: Codici uscita standard per automazione
- **JSON Output**: Output JSON per integrazione tools

## 🎮 Parametri Comuni

Tutti gli script supportano parametri standard:

```powershell
# Modalità operative
-DryRun              # Anteprima senza esecuzione
-Force               # Salta conferme (automazione)
-Verbose             # Output dettagliato
-Quiet               # Output minimale

# Configurazione
-Environment <env>   # dev|staging|prod|openshift-local
-Profile <profile>   # Profilo Spring Boot
-Port <port>         # Porta personalizzata
-Instances <count>   # Numero istanze

# Debugging
-Debug               # Modalità debug
-LogLevel <level>    # trace|debug|info|warn|error
-LogFile <file>      # File log personalizzato
```

## 🆘 Supporto e Troubleshooting

### 📞 Contatti
- **Autore**: Antonio Galluzzi
- **Email**: antonio.galluzzi91@gmail.com
- **GitHub**: [@antoniogalluzzi](https://github.com/antoniogalluzzi)

### 🔍 Troubleshooting
```powershell
# Verifica prerequisiti
.\scripts\utilities\environment-check.ps1

# Diagnostica problemi
.\scripts\maintenance\troubleshoot-issues.ps1 -Interactive

# Analisi log
.\scripts\utilities\log-analyzer.ps1 -Last 1hour
```

### 📚 Documentazione
- **Documentazione Completa**: [DOCUMENTATION.md](../DOCUMENTATION.md)
- **API Reference**: [README.md](../README.md)
- **Changelog**: [CHANGELOG.md](../CHANGELOG.md)

---

## 🎉 Getting Started

Scegli il tuo scenario e inizia subito:

**🏃‍♂️ Sviluppo rapido**:
```powershell
.\scripts\setup\setup-dev-environment.ps1 -Quick
```

**🏗️ Deploy completo**:
```powershell
.\scripts\setup\setup-openshift-local.ps1 -Command release
```

**☁️ Cloud deployment**:
```powershell
.\scripts\setup\setup-cloud-aws.ps1 -Environment production
```

**Happy scripting!** 🚀
