#!/bin/bash
# OpenShift Local Setup Script for Hazelcast Demo
# Usage: ./setup-openshift-local.sh [start|stop|deploy|cleanup]

set -e

PROJECT_NAME="hazelcast-demo-dev"
APP_NAME="hazelcast-demo"
DB_NAME="postgresql"
DB_USER="hazelcast"
DB_PASSWORD="hazelcast123"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_crc() {
    if ! command -v crc &> /dev/null; then
        log_error "CRC (OpenShift Local) is not installed or not in PATH"
        log_info "Download from: https://console.redhat.com/openshift/create/local"
        exit 1
    fi
}

check_oc() {
    if ! command -v oc &> /dev/null; then
        log_error "OpenShift CLI (oc) is not installed or not in PATH"
        log_info "Download from: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html"
        exit 1
    fi
}

start_crc() {
    log_info "Starting OpenShift Local..."
    crc setup
    crc start --cpus 4 --memory 8192

    log_info "Configuring OpenShift CLI..."
    eval $(crc oc-env)

    log_success "OpenShift Local started successfully!"
    log_info "Console URL: $(crc console --url)"
    log_info "API URL: https://api.crc.testing:6443"
}

stop_crc() {
    log_info "Stopping OpenShift Local..."
    crc stop
    log_success "OpenShift Local stopped!"
}

login_cluster() {
    log_info "Logging into OpenShift cluster..."
    local password=$(crc console --credentials | grep "Password:" | awk '{print $2}')
    oc login -u kubeadmin -p "$password" https://api.crc.testing:6443 --insecure-skip-tls-verify=true
    log_success "Logged in successfully!"
}

create_project() {
    log_info "Creating project: $PROJECT_NAME"
    oc new-project $PROJECT_NAME 2>/dev/null || log_warning "Project already exists"
    oc project $PROJECT_NAME
    log_success "Project ready!"
}

deploy_database() {
    log_info "Deploying PostgreSQL database..."

    # Check if already exists
    if oc get pods -l app=$DB_NAME &>/dev/null; then
        log_warning "PostgreSQL already deployed"
        return
    fi

    # Deploy PostgreSQL
    oc new-app postgresql-ephemeral \
        --param DATABASE_SERVICE_NAME=$DB_NAME \
        --param POSTGRESQL_DATABASE=hazelcastdb \
        --param POSTGRESQL_USER=$DB_USER \
        --param POSTGRESQL_PASSWORD=$DB_PASSWORD \
        --param POSTGRESQL_VERSION=13

    log_info "Waiting for PostgreSQL to be ready..."
    oc wait --for=condition=ready pod -l app=$DB_NAME --timeout=300s

    log_success "PostgreSQL deployed successfully!"
}

create_db_secret() {
    log_info "Creating database secret..."

    # Check if secret exists
    if oc get secret db-secret &>/dev/null; then
        log_warning "Database secret already exists"
        return
    fi

    oc create secret generic db-secret \
        --from-literal=host=$DB_NAME.$PROJECT_NAME.svc.cluster.local \
        --from-literal=dbname=hazelcastdb \
        --from-literal=username=$DB_USER \
        --from-literal=password=$DB_PASSWORD

    log_success "Database secret created!"
}

build_and_deploy_app() {
    log_info "Building and deploying application..."

    # Create build if it doesn't exist
    if ! oc get bc $APP_NAME &>/dev/null; then
        log_info "Creating build configuration..."
        oc new-build --name=$APP_NAME --binary --image-stream=java:openjdk-21-ubi8:latest
    fi

    # Start build
    log_info "Starting build..."
    oc start-build $APP_NAME --from-dir=. --follow

    # Deploy application
    log_info "Deploying application..."
    oc new-app $APP_NAME:latest \
        --name=$APP_NAME \
        --env=DB_HOST=$DB_NAME.$PROJECT_NAME.svc.cluster.local \
        --env=DB_NAME=hazelcastdb \
        --env=DB_USERNAME=$DB_USER \
        --env=DB_PASSWORD=$DB_PASSWORD

    # Wait for deployment
    log_info "Waiting for application to be ready..."
    oc wait --for=condition=available deployment/$APP_NAME --timeout=300s

    # Scale to 2 replicas for cache testing
    log_info "Scaling to 2 replicas..."
    oc scale deployment $APP_NAME --replicas=2

    log_success "Application deployed successfully!"
}

show_app_info() {
    log_info "Application Information:"
    echo ""
    log_info "Routes:"
    oc get routes
    echo ""
    log_info "Pods:"
    oc get pods
    echo ""
    log_info "Services:"
    oc get services
    echo ""

    local route=$(oc get routes -o jsonpath='{.items[0].spec.host}' 2>/dev/null)
    if [ ! -z "$route" ]; then
        log_success "Application URL: http://$route"
        log_info "Swagger UI: http://$route/swagger-ui.html"
        log_info "API Docs: http://$route/v3/api-docs"
        log_info "Health Check: http://$route/actuator/health"
    log_info "Actuator Metrics endpoint: http://$route/actuator/metrics"
    fi
}

test_application() {
    log_info "Testing application..."

    local route=$(oc get routes -o jsonpath='{.items[0].spec.host}' 2>/dev/null)
    if [ -z "$route" ]; then
        log_error "No route found. Is the application deployed?"
        return 1
    fi

    # Test health endpoint
    if curl -s http://$route/actuator/health | grep -q "UP"; then
        log_success "Health check: PASSED"
    else
        log_error "Health check: FAILED"
    fi

    # Test API
    if curl -s -X POST http://$route/user \
        -H "Content-Type: application/json" \
        -d '{"name": "Test User"}' | grep -q "id"; then
        log_success "Create user: PASSED"
    else
        log_error "Create user: FAILED"
    fi

    # Test cache
    if curl -s http://$route/user/1 | grep -q "name"; then
        log_success "Get user (cache test): PASSED"
    else
        log_error "Get user (cache test): FAILED"
    fi

    log_success "Application testing completed!"
}

cleanup() {
    log_warning "Cleaning up OpenShift Local environment..."
    oc delete project $PROJECT_NAME 2>/dev/null || true
    log_success "Cleanup completed!"
}

show_help() {
    echo "OpenShift Local Setup Script for Hazelcast Demo"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Start OpenShift Local and setup environment"
    echo "  stop      - Stop OpenShift Local"
    echo "  deploy    - Deploy database and application"
    echo "  test      - Test the deployed application"
    echo "  cleanup   - Remove all resources"
    echo "  info      - Show application information"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start    # Start CRC and setup"
    echo "  $0 deploy   # Deploy everything"
    echo "  $0 test     # Test application"
}

main() {
    case "${1:-help}" in
        "start")
            check_crc
            start_crc
            login_cluster
            create_project
            ;;
        "stop")
            check_crc
            stop_crc
            ;;
        "deploy")
            check_oc
            deploy_database
            create_db_secret
            build_and_deploy_app
            show_app_info
            ;;
        "test")
            check_oc
            test_application
            ;;
        "cleanup")
            check_oc
            cleanup
            ;;
        "info")
            check_oc
            show_app_info
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

main "$@"
