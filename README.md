# Go + Kubernetes + Skaffold with Hot Reload + Istio Service Mesh

A production-like Go HTTP server deployed to Kubernetes with Skaffold, Air for hot reloading, and Istio service mesh for advanced traffic management and observability.

## Features

- Simple Go HTTP server with JSON endpoints
- Hot reload with Air (code changes automatically rebuild and restart the app)
- Skaffold for streamlined Kubernetes development
- File sync for instant code updates
- Health check endpoints
- Istio service mesh integration with:
  - Traffic management (retries, timeouts, circuit breaking)
  - Load balancing and connection pooling
  - mTLS encryption between services
  - Distributed tracing and observability
  - Ready for canary deployments
- Production-like environment for local development

## Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://docs.docker.com/get-docker/) - Container runtime
- [Kubernetes](https://kubernetes.io/docs/setup/) - Local cluster (minikube, Docker Desktop, or kind)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Skaffold](https://skaffold.dev/docs/install/) - Kubernetes development tool
- [Istio](https://istio.io/latest/docs/setup/getting-started/) - Service mesh (see ISTIO_SETUP.md for installation)
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
├── main.go                        # Go HTTP server with JSON endpoints
├── go.mod                         # Go module definition
├── Dockerfile                     # Docker image with Air for hot reload
├── .air.toml                      # Air configuration for hot reloading
├── skaffold.yaml                  # Skaffold configuration
├── k8s/
│   ├── deployment.yaml            # Kubernetes deployment with Istio sidecar
│   ├── service.yaml               # Kubernetes service
│   ├── istio-gateway.yaml         # Istio ingress gateway configuration
│   ├── istio-virtualservice.yaml  # Istio traffic routing rules
│   └── istio-destinationrule.yaml # Istio traffic policies
├── README.md                      # This file
└── ISTIO_SETUP.md                 # Istio installation and configuration guide
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

## Istio Service Mesh

This project includes full Istio service mesh integration for a production-like development environment. Istio provides advanced traffic management, security, and observability features without requiring changes to your application code.

### Installing Istio

#### Step 1: Download Istio

Download the latest Istio release and add the `istioctl` CLI to your PATH:

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
```

#### Step 2: Install Istio with Demo Profile

For a production-like setup with all features enabled:

```bash
istioctl install --set profile=demo -y
```

This installs the core Istio components:
- **Istiod** - Control plane that manages and configures the proxies
- **Istio Ingress Gateway** - Handles incoming traffic to your services
- **Istio Egress Gateway** - Controls outbound traffic from the mesh

#### Step 3: Install Observability Addons

The observability tools (Prometheus, Grafana, Kiali, Jaeger) are installed separately:

```bash
kubectl apply -f istio-*/samples/addons/prometheus.yaml
kubectl apply -f istio-*/samples/addons/grafana.yaml
kubectl apply -f istio-*/samples/addons/kiali.yaml
kubectl apply -f istio-*/samples/addons/jaeger.yaml
```

Wait for the addon pods to be ready:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n istio-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=grafana -n istio-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=120s
kubectl wait --for=condition=ready pod -l app=jaeger -n istio-system --timeout=120s
```

#### Step 4: Verify Installation

Check that all Istio components and addons are running:

```bash
kubectl get pods -n istio-system
```

You should see pods for:
- `istiod`
- `istio-ingressgateway`
- `istio-egressgateway`
- `prometheus`
- `grafana`
- `kiali`
- `jaeger`

Wait until all pods show `Running` status. This may take a few minutes.

### Quick Setup with Makefile

Alternatively, use the included Makefile for automated setup:

```bash
# Complete setup (installs Istio + observability addons)
make setup

# Or install components individually:
make install-istio      # Install Istio core components
make install-addons     # Install Prometheus, Grafana, Kiali, Jaeger

# Verify all prerequisites
make verify-all

# View all available commands
make help
```

The Makefile provides convenient commands for:
- Cluster management (`make minikube-start` or `make kind-start`)
- Istio installation and addon setup
- Development workflow (`make dev`, `make build`, `make deploy`)
- Testing (`make test`, `make traffic`)
- Opening dashboards (`make dashboard-kiali`, `make dashboard-prometheus`, etc.)
- Status and debugging (`make status`, `make logs`, `make istio-analyze`)

### Running the Application with Istio

Once Istio is installed, simply run:

```bash
skaffold dev
```

Skaffold will automatically:
1. Build your Docker image
2. Deploy all Kubernetes manifests (including Istio resources)
3. Inject the Istio sidecar proxy into your application pod
4. Port-forward the Istio ingress gateway to `localhost:8080`
5. Stream logs and watch for file changes

Your application now runs with the full power of the service mesh!

### What Istio Provides

#### Traffic Management

The Istio configuration in this project includes:

- **Gateway** (`k8s/istio-gateway.yaml`): Manages ingress traffic into the service mesh
- **VirtualService** (`k8s/istio-virtualservice.yaml`): Defines routing rules with:
  - **30-second timeout**: Prevents requests from hanging indefinitely
  - **Automatic retries**: Retries failed requests (5xx errors, connection failures)
  - **Intelligent routing**: Route traffic based on headers, paths, or other criteria

- **DestinationRule** (`k8s/istio-destinationrule.yaml`): Configures traffic policies:
  - **Connection pooling**: Max 100 TCP connections per service
  - **Load balancing**: LEAST_REQUEST algorithm distributes traffic to least-busy instances
  - **Circuit breaking**: Automatically removes unhealthy instances from rotation
  - **Outlier detection**: Identifies and ejects failing instances
  - **Service subsets**: Enables canary deployments and A/B testing

#### Security Features

Istio automatically provides:
- **mTLS encryption**: All service-to-service communication is encrypted
- **Authentication**: Verify the identity of services
- **Authorization policies**: Control which services can communicate
- **Certificate management**: Automatic cert rotation and distribution

#### Observability and Monitoring

**Note**: Make sure you've installed the observability addons first (see Step 3 above or run `make install-addons`).

Access the Istio observability dashboards to monitor your services:

##### Kiali - Service Mesh Dashboard
Visualize your service mesh topology, traffic flow, and health:
```bash
istioctl dashboard kiali
```

Features:
- Real-time service graph showing traffic flow
- Request rates, error rates, and latencies
- Configuration validation
- Service health indicators

##### Grafana - Metrics and Dashboards
View detailed performance metrics and pre-built dashboards:
```bash
istioctl dashboard grafana
```

Includes dashboards for:
- Istio mesh metrics
- Service performance
- Workload metrics
- Control plane monitoring

##### Jaeger - Distributed Tracing
Trace requests as they flow through your services:
```bash
istioctl dashboard jaeger
```

See:
- End-to-end request traces
- Service dependencies
- Latency breakdown
- Error tracking

##### Prometheus - Raw Metrics
Query raw metrics directly:
```bash
istioctl dashboard prometheus
```

### Testing Traffic Management Features

#### Generate Test Traffic

Generate traffic to see Istio features in action:

```bash
# In another terminal, run this to generate continuous traffic
for i in {1..100}; do
  curl http://localhost:8080/
  curl http://localhost:8080/health
  curl http://localhost:8080/api
  sleep 0.1
done
```

#### View Traffic in Kiali

1. Open Kiali: `istioctl dashboard kiali`
2. Navigate to **Graph** in the left sidebar
3. Select your namespace from the dropdown
4. Watch real-time traffic flow between services
5. Try different graph types: App graph, Workload graph, Service graph

You'll see:
- Request volume between services
- Success/error rates
- Response times
- Traffic patterns

### Production-Ready Features

With Istio enabled, your application automatically gains:

1. **Circuit Breaking**: Unhealthy instances are automatically removed from the load balancer pool
2. **Automatic Retries**: Failed requests are retried without client intervention
3. **Request Timeouts**: Long-running requests are terminated to prevent resource exhaustion
4. **Smart Load Balancing**: LEAST_REQUEST algorithm sends traffic to least-loaded instances
5. **Connection Pooling**: Limits prevent overwhelming downstream services
6. **mTLS Encryption**: All service communication is encrypted by default
7. **Distributed Tracing**: Track requests across service boundaries
8. **Metrics Collection**: Detailed performance and health metrics
9. **Traffic Splitting**: Ready for canary deployments with version subsets

### Advanced: Canary Deployments

The DestinationRule defines a `v1` subset, making it easy to add canary deployments:

1. **Deploy a new version** with `version: v2` label:
   ```yaml
   labels:
     app: my-go-app
     version: v2  # Add this label to your new deployment
   ```

2. **Add a v2 subset** to `k8s/istio-destinationrule.yaml`:
   ```yaml
   subsets:
     - name: v1
       labels:
         version: v1
     - name: v2  # Add this
       labels:
         version: v2
   ```

3. **Split traffic** in `k8s/istio-virtualservice.yaml`:
   ```yaml
   http:
     - route:
         - destination:
             host: my-go-app-service
             subset: v1
           weight: 90  # 90% to stable version
         - destination:
             host: my-go-app-service
             subset: v2
           weight: 10  # 10% to canary
   ```

4. **Monitor in Kiali** to see traffic distribution and error rates

### Troubleshooting Istio

#### Check Sidecar Injection

Verify that the Istio sidecar was injected into your pod:

```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'
```

You should see both `my-go-app` and `istio-proxy` containers.

#### View Sidecar Logs

Check the Istio proxy logs for traffic issues:

```bash
kubectl logs <pod-name> -c istio-proxy
```

#### Analyze Configuration

Run Istio's configuration analyzer to detect issues:

```bash
istioctl analyze
```

This will report any misconfigurations or warnings.

#### Check Gateway Status

Verify the ingress gateway is running:

```bash
kubectl get svc -n istio-system istio-ingressgateway
```

### Uninstalling Istio

To completely remove Istio from your cluster:

```bash
istioctl uninstall --purge -y
kubectl delete namespace istio-system
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

- Add database connectivity with Istio traffic management
- Implement authentication/authorization using Istio security policies
- Add more API endpoints and microservices
- Set up CI/CD pipelines
- Deploy to a cloud Kubernetes cluster (GKE, EKS, AKS)
- Explore canary deployments and A/B testing with Istio
- Configure mutual TLS policies and authorization rules

## Resources

- [Skaffold Documentation](https://skaffold.dev/docs/)
- [Air (Hot Reload)](https://github.com/cosmtrek/air)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Go Documentation](https://golang.org/doc/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
