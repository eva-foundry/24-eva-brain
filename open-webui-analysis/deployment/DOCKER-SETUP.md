# Docker Setup: Open WebUI vs EVA-JP

## Open WebUI Docker Architecture

### Multi-Stage Dockerfile Analysis

```dockerfile
# Location: /open-webui/Dockerfile

######## Stage 1: WebUI Frontend Build ########
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build

WORKDIR /app

# Git for version tracking
RUN apk add --no-cache git

# Dependencies first (better caching)
COPY package.json package-lock.json ./
RUN npm ci --force

# Then source code
COPY . .

# Build with hash
ENV APP_BUILD_HASH=${BUILD_HASH}
RUN npm run build

######## Stage 2: Backend Runtime ########
FROM python:3.11.14-slim-bookworm AS base

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8080 \
    ENV=prod

# Install dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy frontend build
COPY --from=build /app/build /app/frontend/build

# Copy backend code
COPY backend/ /app/backend/

# Non-root user
RUN useradd -m -u 1000 appuser
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run app
CMD ["python", "-m", "open_webui"]
```

### Key Multi-Stage Benefits

1. **Smaller Final Image**: 
   - Only production runtime in final stage
   - No build tools (npm, webpack) in production
   - Result: ~500MB vs 2GB+ with build tools

2. **Better Caching**:
   - Dependencies cached separately from code
   - Rebuilds only changed layers
   - Faster CI/CD builds

3. **Security**:
   - Build-time secrets don't reach final image
   - Minimal attack surface
   - Non-root execution

## EVA-JP v1.2 Current Dockerfile

### Current Structure

```dockerfile
# Location: container_images/webapp_container_image/Dockerfile

# Stage 1: Frontend build
FROM node:18 AS frontend
WORKDIR /app/frontend
COPY app/frontend/package*.json ./
RUN npm install
COPY app/frontend .
RUN npm run build

# Stage 2: Backend
FROM python:3.11-slim
WORKDIR /app

# Install Python deps
COPY app/backend/requirements.txt .
RUN pip install -r requirements.txt

# Copy backend code
COPY app/backend /app/backend

# Copy frontend build
COPY --from=frontend /app/frontend/dist /app/static

# Expose port
EXPOSE 8080

# Run
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Issues with Current Dockerfile

❌ **No health check** - Can't detect unhealthy containers  
❌ **Running as root** - Security risk  
❌ **No build args** - Not flexible for different environments  
❌ **No .dockerignore** - Includes unnecessary files  
❌ **No layer optimization** - Rebuilds too much  
❌ **No security scanning** - Unknown vulnerabilities

## Improved EVA Dockerfile

### Enhanced Multi-Stage Build

```dockerfile
# syntax=docker/dockerfile:1
# container_images/webapp_container_image/Dockerfile

######## Arguments ########
ARG PYTHON_VERSION=3.11
ARG NODE_VERSION=22
ARG BUILD_ENV=production
ARG BUILD_HASH=dev-build

######## Stage 1: Frontend Build ########
FROM node:${NODE_VERSION}-alpine AS frontend-build

# Build args
ARG BUILD_ENV
ARG BUILD_HASH

WORKDIR /app/frontend

# Install dependencies first (better caching)
COPY app/frontend/package.json app/frontend/package-lock.json ./
RUN npm ci --silent

# Copy source and build
COPY app/frontend ./
ENV VITE_BUILD_HASH=${BUILD_HASH}
ENV NODE_ENV=${BUILD_ENV}
RUN npm run build

# Verify build output
RUN test -f dist/index.html || (echo "Build failed" && exit 1)

######## Stage 2: Backend Dependencies ########
FROM python:${PYTHON_VERSION}-slim-bookworm AS backend-deps

# System dependencies
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY app/backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir uvicorn[standard] gunicorn

######## Stage 3: Final Runtime ########
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

# Build args
ARG BUILD_HASH
ARG BUILD_ENV

# Labels for metadata
LABEL maintainer="eva-team@esdc.gc.ca" \
      version="1.2.0" \
      description="EVA Jurisprudence Assistant" \
      build_hash="${BUILD_HASH}" \
      build_env="${BUILD_ENV}"

# Runtime environment
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    ENV=${BUILD_ENV} \
    BUILD_HASH=${BUILD_HASH}

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -g 1000 appgroup && \
    useradd -r -u 1000 -g appgroup appuser && \
    mkdir -p /app /app/data /app/logs && \
    chown -R appuser:appgroup /app

WORKDIR /app

# Copy Python packages from deps stage
COPY --from=backend-deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend-deps /usr/local/bin/uvicorn /usr/local/bin/uvicorn
COPY --from=backend-deps /usr/local/bin/gunicorn /usr/local/bin/gunicorn

# Copy backend code
COPY --chown=appuser:appgroup app/backend ./backend

# Copy frontend build
COPY --from=frontend-build --chown=appuser:appgroup /app/frontend/dist ./static

# Copy startup script
COPY --chown=appuser:appgroup scripts/start.sh ./
RUN chmod +x start.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

# Entrypoint
ENTRYPOINT ["./start.sh"]
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8080"]
```

### Enhanced .dockerignore

```bash
# .dockerignore (create this file)

# Git
.git
.gitignore
.github

# Python
__pycache__
*.py[cod]
*$py.class
*.so
.Python
*.egg-info
.venv
venv/
env/

# Node
node_modules/
npm-debug.log
yarn-error.log
.npm

# IDE
.vscode
.idea
*.swp
*.swo

# Testing
.pytest_cache
.coverage
htmlcov/
*.log

# Docs
docs/
*.md
!README.md

# Build artifacts
dist/
build/
*.tar.gz

# Environment files (secrets)
.env
*.env
!.env.example

# Logs
logs/
*.log
backend-logs*/
auth-*-logs/

# OS
.DS_Store
Thumbs.db

# Containers
docker-compose*.yml
Dockerfile*
!Dockerfile
```

### Startup Script

```bash
#!/bin/bash
# scripts/start.sh

set -e

echo "🚀 Starting EVA Jurisprudence Assistant"
echo "Build: $BUILD_HASH"
echo "Environment: $ENV"

# Wait for dependencies (if needed)
if [ -n "$WAIT_FOR_COSMOS" ]; then
    echo "⏳ Waiting for Cosmos DB..."
    # Add health check logic
fi

# Run database migrations (if applicable)
if [ "$ENV" = "production" ]; then
    echo "📦 Running migrations..."
    # Add migration logic
fi

# Start the application
echo "✅ Starting application on port $PORT"

# Production: Use Gunicorn with multiple workers
if [ "$ENV" = "production" ]; then
    exec gunicorn backend.app:app \
        --bind 0.0.0.0:$PORT \
        --workers 4 \
        --worker-class uvicorn.workers.UvicornWorker \
        --access-logfile - \
        --error-logfile - \
        --log-level info
else
    # Development: Use Uvicorn with reload
    exec uvicorn backend.app:app \
        --host 0.0.0.0 \
        --port $PORT \
        --reload
fi
```

## Docker Compose Comparison

### Open WebUI docker-compose.yaml

```yaml
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    volumes:
      - open-webui:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    restart: always
    depends_on:
      - ollama
    networks:
      - webui-network

  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama:/root/.ollama
    restart: always
    networks:
      - webui-network

  redis:
    image: redis:7-alpine
    container_name: redis
    volumes:
      - redis-data:/data
    restart: always
    networks:
      - webui-network

volumes:
  open-webui:
  ollama:
  redis-data:

networks:
  webui-network:
    driver: bridge
```

### EVA docker-compose.yaml (Enhanced)

```yaml
version: '3.8'

services:
  eva-backend:
    build:
      context: .
      dockerfile: container_images/webapp_container_image/Dockerfile
      args:
        BUILD_ENV: ${BUILD_ENV:-development}
        BUILD_HASH: ${BUILD_HASH:-local-dev}
    container_name: eva-backend
    ports:
      - "8080:8080"
    environment:
      # Azure Configuration
      - AZURE_TENANT_ID=${AZURE_TENANT_ID}
      - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
      - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
      - AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT}
      - AZURE_STORAGE_KEY=${AZURE_STORAGE_KEY}
      - AZURE_AI_SEARCH_ENDPOINT=${AZURE_AI_SEARCH_ENDPOINT}
      - AZURE_AI_SEARCH_KEY=${AZURE_AI_SEARCH_KEY}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY}
      - AZURE_COSMOS_ENDPOINT=${AZURE_COSMOS_ENDPOINT}
      - AZURE_COSMOS_KEY=${AZURE_COSMOS_KEY}
      
      # App Configuration
      - ENV=${BUILD_ENV:-development}
      - ENABLE_DEV_CODE=${ENABLE_DEV_CODE:-true}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      
      # Redis (for caching)
      - REDIS_URL=redis://redis:6379
    volumes:
      # Development mode: mount code for hot reload
      - ./app/backend:/app/backend:ro
      - app-data:/app/data
      - app-logs:/app/logs
    depends_on:
      - redis
    restart: unless-stopped
    networks:
      - eva-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  redis:
    image: redis:7-alpine
    container_name: eva-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes
    restart: unless-stopped
    networks:
      - eva-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # Optional: Local Qdrant for development
  qdrant:
    image: qdrant/qdrant:latest
    container_name: eva-qdrant
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant-data:/qdrant/storage
    restart: unless-stopped
    networks:
      - eva-network
    profiles:
      - dev

  # Optional: Nginx reverse proxy
  nginx:
    image: nginx:alpine
    container_name: eva-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - nginx-logs:/var/log/nginx
    depends_on:
      - eva-backend
    restart: unless-stopped
    networks:
      - eva-network
    profiles:
      - production

volumes:
  app-data:
  app-logs:
  redis-data:
  qdrant-data:
  nginx-logs:

networks:
  eva-network:
    driver: bridge
```

## Build Commands Comparison

### Open WebUI Build Commands

```bash
# Standard build
docker build -t open-webui:latest .

# GPU support (CUDA)
docker build \
  --build-arg USE_CUDA=true \
  --build-arg USE_CUDA_VER=cu128 \
  -t open-webui:cuda .

# Development build
docker build \
  --target build \
  -t open-webui:dev .

# Multi-platform
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t open-webui:multi \
  --push .
```

### EVA Enhanced Build Commands

```bash
# Development build
docker build \
  --build-arg BUILD_ENV=development \
  --build-arg BUILD_HASH=$(date +%Y%m%d-%H%M%S) \
  -t eva-backend:dev \
  -f container_images/webapp_container_image/Dockerfile \
  .

# Production build
docker build \
  --build-arg BUILD_ENV=production \
  --build-arg BUILD_HASH=$GIT_COMMIT_SHA \
  -t eva-backend:prod \
  -f container_images/webapp_container_image/Dockerfile \
  .

# Build with caching (faster CI/CD)
docker build \
  --cache-from eva-backend:latest \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t eva-backend:latest \
  -f container_images/webapp_container_image/Dockerfile \
  .

# Azure Container Registry build
az acr build \
  --registry marcosandacr20260203 \
  --image webapp:$(date +%Y%m%d-%H%M%S) \
  --build-arg BUILD_ENV=production \
  --build-arg BUILD_HASH=$BUILD_ID \
  --file container_images/webapp_container_image/Dockerfile \
  .

# Security scan after build
docker scan eva-backend:latest
```

## Azure Container Apps Deployment

### Container App Configuration

```yaml
# azure-container-app.yaml
properties:
  managedEnvironmentId: /subscriptions/.../Microsoft.App/managedEnvironments/eva-env
  configuration:
    activeRevisionsMode: Single
    ingress:
      external: true
      targetPort: 8080
      allowInsecure: false
      traffic:
        - weight: 100
          latestRevision: true
    secrets:
      - name: azure-storage-key
        value: ${AZURE_STORAGE_KEY}
      - name: azure-cosmos-key
        value: ${AZURE_COSMOS_KEY}
      - name: azure-openai-key
        value: ${AZURE_OPENAI_KEY}
    registries:
      - server: marcosandacr20260203.azurecr.io
        identity: system
  template:
    containers:
      - name: eva-backend
        image: marcosandacr20260203.azurecr.io/webapp:latest
        resources:
          cpu: 1.0
          memory: 2Gi
        env:
          - name: AZURE_STORAGE_ACCOUNT
            value: evastorageaccount
          - name: AZURE_STORAGE_KEY
            secretRef: azure-storage-key
          - name: AZURE_COSMOS_ENDPOINT
            value: https://evacosmos.documents.azure.com:443/
          - name: AZURE_COSMOS_KEY
            secretRef: azure-cosmos-key
          - name: ENV
            value: production
        probes:
          liveness:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 30
          readiness:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
    scale:
      minReplicas: 1
      maxReplicas: 10
      rules:
        - name: http-scaling
          http:
            metadata:
              concurrentRequests: '50'
```

### Deployment Script

```bash
#!/bin/bash
# scripts/deploy-to-azure.sh

set -e

# Variables
RESOURCE_GROUP="EsDAICoE-Sandbox"
REGISTRY="marcosandacr20260203"
APP_NAME="eva-backend"
IMAGE_TAG=$(date +%Y%m%d-%H%M%S)

echo "🏗️ Building container image..."
az acr build \
  --registry $REGISTRY \
  --image webapp:$IMAGE_TAG \
  --build-arg BUILD_ENV=production \
  --file container_images/webapp_container_image/Dockerfile \
  .

echo "🏷️ Tagging as latest..."
az acr update \
  --name $REGISTRY \
  --image webapp:$IMAGE_TAG \
  --set webapp:latest

echo "🚀 Deploying to Container App..."
az containerapp update \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $REGISTRY.azurecr.io/webapp:$IMAGE_TAG

echo "⏳ Waiting for deployment..."
az containerapp revision list \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" \
  --output tsv

echo "✅ Deployment complete!"
echo "🌐 URL: https://$APP_NAME.azurewebsites.net"
```

## Best Practices Summary

### From Open WebUI

1. ✅ **Multi-stage builds** - Small final image
2. ✅ **Layer optimization** - Dependencies cached separately
3. ✅ **Non-root user** - Security best practice
4. ✅ **Health checks** - Container orchestration
5. ✅ **Build args** - Flexibility
6. ✅ **Proper labels** - Metadata tracking

### For EVA

1. ✅ Adopt multi-stage pattern
2. ✅ Add comprehensive .dockerignore
3. ✅ Implement health checks
4. ✅ Run as non-root user
5. ✅ Use build args for flexibility
6. ✅ Add startup script for initialization
7. ✅ Security scanning in CI/CD
8. ✅ Proper Azure integration

## Next Steps

1. Implement enhanced Dockerfile
2. Create .dockerignore file
3. Add startup script
4. Update docker-compose.yaml
5. Test local development workflow
6. Update CI/CD pipelines
7. Deploy to staging
8. Performance testing

---

**Created**: 2026-02-07  
**Focus**: Docker best practices from Open WebUI  
**Status**: Ready for implementation
