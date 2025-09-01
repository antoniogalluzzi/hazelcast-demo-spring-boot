# Quick Test Commands for OpenShift Local

# After deployment, test your application with these commands:

## 1. Check Application Status
oc get pods
oc get routes
oc get services

## 2. Test Health Endpoint
curl http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/actuator/health

## 3. Test API Endpoints
# Create a user
curl -X POST http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User"}'

# Get the user (test cache)
curl http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/user/1

## 4. Test Cache Distribution
# Create user from pod 1
oc exec $(oc get pods -l app=hazelcast-demo -o jsonpath='{.items[0].metadata.name}') -- \
  curl -X POST http://localhost:8080/user -H "Content-Type: application/json" -d '{"name": "Pod Test"}'

# Retrieve from pod 2 (should hit cache)
oc exec $(oc get pods -l app=hazelcast-demo -o jsonpath='{.items[1].metadata.name}') -- \
  curl http://localhost:8080/user/2

## 5. Monitor Application
# View logs
oc logs -f deployment/hazelcast-demo

# Check Hazelcast cluster
oc exec $(oc get pods -l app=hazelcast-demo -o jsonpath='{.items[0].metadata.name}') -- \
  curl http://localhost:5701/hazelcast/health

## 6. Access Web Interfaces
# Get application URL
echo "Application URL: http://$(oc get routes -o jsonpath='{.items[0].spec.host}')"
echo "Swagger UI: http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/swagger-ui.html"
echo "API Docs: http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/v3/api-docs"

## 7. Database Operations
# Connect to PostgreSQL
oc rsh $(oc get pods -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
psql -h localhost -U hazelcast hazelcastdb

# Check data
SELECT * FROM users;

## 8. Performance Testing
# Simple load test
for i in {1..10}; do
  curl -s http://$(oc get routes -o jsonpath='{.items[0].spec.host}')/user/1 > /dev/null &
done

# Monitor response times


## 9. Troubleshooting
# Check pod status
oc describe pod $(oc get pods -l app=hazelcast-demo -o jsonpath='{.items[0].metadata.name}')

# View detailed logs
oc logs $(oc get pods -l app=hazelcast-demo -o jsonpath='{.items[0].metadata.name}') --previous

# Check resource usage
oc top pods

## 10. Cleanup
# Remove everything
oc delete project hazelcast-demo-dev

# Stop CRC
crc stop
