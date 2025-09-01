# Environment Configurations - Documentation

> **⚠️ ATTENZIONE:** Questo file è solo **documentazione** e **non** un file di configurazione da usare direttamente!
>
> Per le configurazioni reali, usa i file in `src/main/resources/application-*.yml`

## Scopo di Questo File

Questo documento mostra **esempi di configurazione** per diversi ambienti di deployment. Serve come:

- 📚 **Guida di riferimento** per capire le differenze tra ambienti
- 🔧 **Template** per creare configurazioni personalizzate
- 📋 **Documentazione** delle best practices per ogni ambiente

## File di Configurazione Reali

I veri file di configurazione sono in `src/main/resources/`:

- `application-dev.yml` - Sviluppo locale
- `application-staging.yml` - Ambiente di staging
- `application-prod.yml` - Ambiente di produzione

## Development Environment
```yaml
spring:
  profiles:
    active: dev
  datasource:
    url: jdbc:postgresql://localhost:5432/hazelcastdb
    username: postgres
    password: dev_password
  jpa:
    show-sql: true
    hibernate:
      ddl-auto: create-drop

hazelcast:
  network:
    join:
      multicast:
        enabled: true

logging:
  level:
    com.example: DEBUG
    org.springframework: INFO
```

## Staging Environment
```yaml
spring:
  profiles:
    active: staging
  datasource:
    url: jdbc:postgresql://${DB_HOST:staging-db}:5432/hazelcastdb
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate

hazelcast:
  network:
    join:
      tcp-ip:
        enabled: true
        members:
          - staging-hazelcast-1:5701
          - staging-hazelcast-2:5701

logging:
  level:
    com.example: INFO
    org.springframework: WARN
```

## Production Environment
```yaml
spring:
  profiles:
    active: prod
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 50
      minimum-idle: 10
  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        jdbc:
          batch_size: 25
        order_inserts: true
        order_updates: true

hazelcast:
  network:
    join:
      kubernetes:
        enabled: true
        namespace: ${KUBERNETES_NAMESPACE}
        service-name: hazelcast-demo-service
  map:
    users:
      time-to-live-seconds: 3600
      max-idle-seconds: 1800

logging:
  level:
    com.example: INFO
    org.springframework: WARN
    org.hibernate: ERROR

management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized
```
