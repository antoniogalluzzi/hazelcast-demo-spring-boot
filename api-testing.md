# API Testing Examples

## Using Swagger UI

1. **Start the application**:
   ```bash
   java -jar target/hazelcast-demo-0.0.1-SNAPSHOT.jar
   ```

2. **Open Swagger UI**:
   - Navigate to: http://localhost:8080/swagger-ui.html
   - Or JSON spec: http://localhost:8080/v3/api-docs

3. **Test User Creation**:
   - Expand `POST /user` endpoint
   - Click "Try it out"
   - Enter JSON: `{"name": "Mario Rossi"}`
   - Click "Execute"

4. **Test User Retrieval**:
   - Expand `GET /user/{id}` endpoint
   - Enter ID: `1`
   - Click "Execute"

## Using cURL

### Create User
```bash
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Mario Rossi"}'
```

### Get User
```bash
curl http://localhost:8080/user/1
```

### Health Check
```bash
curl http://localhost:8080/actuator/health
```

### Prometheus Metrics
```bash
curl http://localhost:8080/actuator/prometheus
```

## Using Postman

### Import OpenAPI Spec
1. Export JSON from: http://localhost:8080/v3/api-docs
2. Import into Postman
3. Create environment with:
   - `baseUrl`: `http://localhost:8080`
   - `userId`: `1`

### Example Collection
```json
{
  "info": {
    "name": "Hazelcast Demo API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
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
          "raw": "{\"name\": \"Mario Rossi\"}"
        },
        "url": {
          "raw": "{{baseUrl}}/user",
          "host": ["{{baseUrl}}"],
          "path": ["user"]
        }
      }
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
        }
      }
    }
  ]
}
```

## Load Testing

### Using Apache Bench
```bash
# Create user load test
ab -n 1000 -c 10 -p create_user.json -T application/json http://localhost:8080/user

# Get user load test
ab -n 1000 -c 10 http://localhost:8080/user/1
```

### Using JMeter
1. Create Thread Group (100 users, 10 seconds ramp-up)
2. Add HTTP Request for `/user` POST
3. Add JSON body: `{"name": "Test User ${__threadNum}"}`
4. Add listeners for results

## Performance Benchmarks

### Expected Performance
- **Response Time**: < 50ms for cached requests
- **Throughput**: 500+ req/sec per pod
- **Cache Hit Rate**: > 90%
- **Memory Usage**: < 512MB per pod

### Monitoring During Load Test
```bash
# Watch metrics during test
watch -n 1 'curl -s http://localhost:8080/actuator/metrics/http.server.requests | jq .measurements[0]'

# Monitor cache performance
curl http://localhost:8080/actuator/prometheus | grep hazelcast
```
