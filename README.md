# Go + Kubernetes + Skaffold with Hot Reload

A simple Go HTTP server deployed to Kubernetes with Skaffold and Air for hot reloading during development.

## Features

- Simple Go HTTP server with JSON endpoints
- Hot reload with Air (code changes automatically rebuild and restart the app)
- Skaffold for streamlined Kubernetes development
- File sync for instant code updates
- Health check endpoints
- Ready for local Kubernetes development

## Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/) - Container runtime
- [Kubernetes](https://kubernetes.io/docs/setup/) - Local cluster (minikube, Docker Desktop, or kind)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Skaffold](https://skaffold.dev/docs/install/) - Kubernetes development tool
- [Go 1.21+](https://golang.org/doc/install) - (optional, for local development)

### Quick Install Commands

```bash
# Install Skaffold (macOS)
brew install skaffold

# Install Skaffold (Linux)
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
sudo install skaffold /usr/local/bin/

# Verify installations
docker --version
kubectl version --client
skaffold version
```

## Project Structure

```
.
├── main.go              # Go HTTP server with JSON endpoints
├── go.mod               # Go module definition
├── Dockerfile           # Docker image with Air for hot reload
├── .air.toml            # Air configuration for hot reloading
├── skaffold.yaml        # Skaffold configuration
├── k8s/
│   ├── deployment.yaml  # Kubernetes deployment manifest
│   └── service.yaml     # Kubernetes service manifest
└── README.md            # This file
```

## API Endpoints

The server exposes the following JSON endpoints:

- `GET /` - Hello message with timestamp
- `GET /health` - Health check endpoint (used by Kubernetes probes)
- `GET /api` - API test endpoint
- `POST /api` - Echo JSON data back with timestamp

## Getting Started

### 1. Start Your Kubernetes Cluster

Make sure your Kubernetes cluster is running:

```bash
# For Docker Desktop: Enable Kubernetes in settings

# For minikube:
minikube start

# For kind:
kind create cluster

# Verify cluster is running:
kubectl cluster-info
```

### 2. Run with Skaffold

Start the development environment with hot reload:

```bash
skaffold dev
```

This command will:
- Build the Docker image
- Deploy to Kubernetes
- Set up file sync for hot reloading
- Forward port 8080 to localhost
- Stream logs to your terminal
- Watch for file changes and auto-reload

### 3. Test the Application

Once Skaffold is running, open a new terminal and test the endpoints:

```bash
# Hello endpoint
curl http://localhost:8080/

# Health check
curl http://localhost:8080/health

# API GET request
curl http://localhost:8080/api

# API POST request
curl -X POST http://localhost:8080/api \
  -H "Content-Type: application/json" \
  -d '{"name": "John", "message": "Hello World"}'
```

### 4. Make Changes and See Hot Reload

Try editing `main.go` and save the file. Air will automatically:
- Detect the change
- Rebuild the application
- Restart the server
- You'll see the changes reflected immediately

Example: Change the message in the `helloHandler` function and save.

## Development Workflow

### Running in Development Mode

```bash
# Start with hot reload and port forwarding
skaffold dev

# Run in the background
skaffold dev --port-forward
```

### Building for Production

```bash
# Build the image
skaffold build

# Run once (no file watching)
skaffold run

# Clean up resources
skaffold delete
```

### Debugging

```bash
# View logs
kubectl logs -f deployment/my-go-app

# View pod status
kubectl get pods

# Describe pod for troubleshooting
kubectl describe pod <pod-name>

# Execute commands in the pod
kubectl exec -it <pod-name> -- sh
```

## How Hot Reload Works

1. **Skaffold File Sync**: Monitors Go files and syncs changes to the container
2. **Air Watcher**: Detects file changes inside the container
3. **Auto Rebuild**: Air rebuilds the binary when changes are detected
4. **Auto Restart**: Air restarts the application with the new binary

Changes to the following files trigger a reload:
- `*.go` files
- `go.mod` / `go.sum`
- `.air.toml`

## Configuration

### Skaffold (`skaffold.yaml`)

- **File Sync**: Enabled for `.go`, `go.mod`, `go.sum`, and `.air.toml` files
- **Port Forward**: Automatically forwards service port 80 to localhost:8080
- **Manifests**: Uses raw YAML from the `k8s/` directory

### Air (`.air.toml`)

- **Watch Patterns**: Monitors `.go`, `.tpl`, `.tmpl`, and `.html` files
- **Exclude**: Ignores test files and tmp directory
- **Build Delay**: 1 second delay before rebuilding

### Kubernetes Resources

- **Deployment**: Single replica with health checks
- **Service**: ClusterIP type exposing port 80
- **Resources**: Memory (64Mi-128Mi), CPU (100m-200m)

## Troubleshooting

### Port Already in Use

If port 8080 is already in use, modify the `localPort` in `skaffold.yaml`:

```yaml
portForward:
  - resourceType: service
    resourceName: my-go-app-service
    port: 80
    localPort: 8081  # Change to an available port
```

### Image Pull Errors

Skaffold builds images locally. Ensure Docker is running:

```bash
docker ps
```

### Pod Not Starting

Check pod logs and events:

```bash
kubectl get pods
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

### File Sync Not Working

Ensure you're running `skaffold dev` (not `skaffold run`). File sync only works in dev mode.

## Customization

### Change Application Port

1. Update port in `main.go`:
   ```go
   port := "3000"
   ```

2. Update `containerPort` in `k8s/deployment.yaml`

3. Update `targetPort` in `k8s/service.yaml`

### Add New Dependencies

```bash
# Add a new Go dependency
go get github.com/some/package

# Skaffold will sync go.mod and go.sum automatically
```

### Modify Resource Limits

Edit `k8s/deployment.yaml` to adjust CPU and memory:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "200m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

## Cleaning Up

To stop Skaffold and remove deployed resources:

```bash
# Press Ctrl+C to stop skaffold dev

# Or delete resources manually:
skaffold delete

# Or use kubectl:
kubectl delete -f k8s/
```

## Next Steps

- Add database connectivity
- Implement authentication/authorization
- Add more API endpoints
- Set up CI/CD pipelines
- Deploy to a cloud Kubernetes cluster (GKE, EKS, AKS)
- Add monitoring and observability

## Resources

- [Skaffold Documentation](https://skaffold.dev/docs/)
- [Air (Hot Reload)](https://github.com/cosmtrek/air)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Go Documentation](https://golang.org/doc/)
