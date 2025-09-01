# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **H2 Database Integration**: Added H2 in-memory database for local development
  - Configured H2 console access at `/h2-console`
  - Updated `application-dev.yml` with H2 connection settings
  - Added H2 dependency to `pom.xml`
- **Multi-Environment Configuration**:
  - Development profile with H2 database and multicast Hazelcast discovery
  - Staging profile with TCP Hazelcast discovery for containerized environments
  - Production profile with Kubernetes Hazelcast discovery
- **Enhanced OpenAPI Documentation**:
  - Added detailed API information (title, version, description)
  - Configured contact information and Apache 2.0 license
  - Added server configurations for local development and OpenShift production
  - Improved Swagger UI with complete metadata
- **Comprehensive Documentation**:
  - `README.md` with deployment instructions for all environments
  - `api-testing.md` with API testing examples
  - `cloud-deployment.md` with cloud deployment guides
  - `openshift-local-guide.md` with OpenShift local setup
- **Containerization Support**:
  - `Dockerfile` for containerized deployment
  - `deployment.yaml` for Kubernetes deployment
  - `grafana-deployment.yaml` and `grafana-dashboard.json` for monitoring
- **Development Tools**:
  - Maven wrapper (`mvnw.cmd`) for consistent builds
  - Quick test commands script (`quick-test-commands.sh`)
  - PowerShell setup script for OpenShift local

### Changed
- **Cross-Platform Documentation**: Updated all guide files for Windows and Linux/Mac compatibility
  - `README.md`: Divided build, Docker, and OpenShift commands into Windows (PowerShell) and Linux/Mac (Bash) sections
  - `openshift-local-guide.md`: Added PowerShell equivalents for all OpenShift CLI commands
  - `cloud-deployment.md`: Separated AWS EKS deployment commands by operating system
  - `api-testing.md`: Added PowerShell cURL commands and monitoring examples
- **SpringDoc OpenAPI**: Updated from incompatible version 2.1.0 to 1.6.9 for Spring Boot 2.7.x compatibility
- **Hazelcast Configuration**: Fixed XML configuration for proper multicast discovery in development
- **Logging Configuration**: Corrected JSON pattern escaping in `logback-spring.xml`

### Fixed
- **Dependency Compatibility**: Resolved SpringDoc OpenAPI version conflict with Spring Boot 2.7.18
- **XML Parsing Errors**: Fixed logback configuration JSON pattern syntax
- **Profile Configuration**: Removed redundant profile declarations in YAML files

### Removed
- **Obsolete Files**: Cleaned up unused configuration files (`environment-configs.yml`)

## [0.1.0] - 2025-09-01

### Added
- Initial Spring Boot 2.7.18 project setup with Java 21
- Hazelcast 5.1.7 distributed caching integration
- Spring Data JPA with User entity and repository
- REST API endpoints for user management with caching
- Micrometer metrics with Prometheus registry
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
