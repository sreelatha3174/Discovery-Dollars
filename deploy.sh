#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

DOCKER_HUB_USERNAME=${1:-""}
DOCKER_HUB_TOKEN=${2:-""}
REGISTRY="docker.io"
NAMESPACE="${DOCKER_HUB_USERNAME}"
BACKEND_IMAGE="${REGISTRY}/${NAMESPACE}/discovery-dollars-backend:latest"
FRONTEND_IMAGE="${REGISTRY}/${NAMESPACE}/discovery-dollars-frontend:latest"
COMPOSE_FILE="docker-compose.yml"
LOG_FILE="deployment.log"

timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
}

log() {
    echo "$(timestamp) $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "${RED}$(timestamp) ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}$(timestamp) $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}$(timestamp) WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

main() {
    log "Starting deployment process..."
    
    if [ -z "$DOCKER_HUB_USERNAME" ] || [ -z "$DOCKER_HUB_TOKEN" ]; then
        error_exit "Docker Hub credentials not provided. Usage: $0 <username> <token>"
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "docker-compose.yml not found in current directory: $(pwd)"
    fi
    
    log "Docker Compose file found: $COMPOSE_FILE"
    
    log "Logging in to Docker Hub..."
    echo "$DOCKER_HUB_TOKEN" | docker login -u "$DOCKER_HUB_USERNAME" --password-stdin "$REGISTRY" 2>/dev/null || error_exit "Failed to login to Docker Hub"
    success "Successfully logged in to Docker Hub"
    
    log "Pulling latest images..."
    
    log "Pulling backend image: $BACKEND_IMAGE"
    docker pull "$BACKEND_IMAGE" || error_exit "Failed to pull backend image"
    success "Backend image pulled successfully"
    
    log "Pulling frontend image: $FRONTEND_IMAGE"
    docker pull "$FRONTEND_IMAGE" || error_exit "Failed to pull frontend image"
    success "Frontend image pulled successfully"
    
    log "Stopping existing containers..."
    docker-compose down || warning "Failed to stop containers or containers not running"
    success "Containers stopped"
    
    log "Pulling MongoDB image..."
    docker pull mongo:7 || warning "Failed to pull MongoDB image, will use local if available"
    
    log "Starting new containers..."
    docker-compose up -d || error_exit "Failed to start containers"
    success "Containers started successfully"
    
    log "Waiting for services to start..."
    sleep 10
    
    log "Checking container status..."
    docker-compose ps
    
    if docker-compose ps | grep -q "backend.*Up" && docker-compose ps | grep -q "frontend.*Up"; then
        success "All services are running"
    else
        error_exit "Some services failed to start. Check docker-compose logs for details"
    fi
    
    log "Logging out from Docker Hub..."
    docker logout "$REGISTRY" 2>/dev/null || true
    
    success "Deployment completed successfully!"
    log "Backend running at http://localhost:8080"
    log "Frontend running at http://localhost:80"
}

main "$@"
