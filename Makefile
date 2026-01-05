.PHONY: help setup install-istio install-addons dev run build deploy clean clean-all status logs test traffic dashboard-kiali dashboard-grafana dashboard-jaeger dashboard-prometheus istio-status istio-analyze minikube-start kind-start verify-all

# Default target - show help
help:
	@echo "🚀 Go + Kubernetes + Skaffold + Istio Demo"
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "Setup & Installation:"
	@echo "  make minikube-start    - Start minikube cluster"
	@echo "  make kind-start        - Start kind cluster"
	@echo "  make install-istio     - Download and install Istio with demo profile"
	@echo "  make install-addons    - Install observability addons (Prometheus, Grafana, Kiali, Jaeger)"
	@echo "  make setup            - Complete setup (cluster + Istio + addons)"
	@echo "  make verify-all       - Verify all prerequisites are installed"
	@echo ""
	@echo "Development:"
	@echo "  make dev              - Run skaffold in dev mode (hot reload)"
	@echo "  make run              - Run skaffold once (no watching)"
	@echo "  make build            - Build Docker image"
	@echo "  make deploy           - Deploy to Kubernetes"
	@echo ""
	@echo "Testing:"
	@echo "  make test             - Test all API endpoints"
	@echo "  make traffic          - Generate continuous test traffic (100 requests)"
	@echo "  make traffic-load     - Generate high load (1000 requests)"
	@echo ""
	@echo "Monitoring & Observability:"
	@echo "  make dashboard-kiali      - Open Kiali dashboard (service mesh)"
	@echo "  make dashboard-grafana    - Open Grafana dashboard (metrics)"
	@echo "  make dashboard-jaeger     - Open Jaeger dashboard (tracing)"
	@echo "  make dashboard-prometheus - Open Prometheus dashboard (raw metrics)"
	@echo "  make dashboards           - Open all dashboards"
	@echo ""
	@echo "Status & Debugging:"
	@echo "  make status           - Show pod, service, and deployment status"
	@echo "  make logs             - Stream application logs"
	@echo "  make istio-status     - Check Istio installation status"
	@echo "  make istio-analyze    - Analyze Istio configuration for issues"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean            - Delete application resources"
	@echo "  make clean-all        - Delete application + uninstall Istio"
	@echo ""

# Verify all prerequisites
verify-all:
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Install from https://docs.docker.com/get-docker/"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
	@command -v skaffold >/dev/null 2>&1 || { echo "❌ Skaffold not found. Install with: brew install skaffold"; exit 1; }
	@echo "✅ Docker:    $$(docker --version)"
	@echo "✅ kubectl:   $$(kubectl version --client --short 2>/dev/null || kubectl version --client)"
	@echo "✅ Skaffold:  $$(skaffold version)"
	@if command -v istioctl >/dev/null 2>&1; then echo "✅ Istio:     $$(istioctl version --short 2>/dev/null || echo 'installed')"; else echo "⚠️  Istio not found. Run 'make install-istio' to install."; fi
	@if kubectl cluster-info >/dev/null 2>&1; then echo "✅ Kubernetes cluster is running"; else echo "⚠️  Kubernetes cluster not running. Run 'make minikube-start' or 'make kind-start'"; fi

# Cluster Management
minikube-start:
	@echo "Starting minikube cluster..."
	minikube start
	@echo "✅ Minikube cluster started"
	kubectl cluster-info

kind-start:
	@echo "Starting kind cluster..."
	kind create cluster --name skaffold-demo
	@echo "✅ Kind cluster started"
	kubectl cluster-info

# Install Istio
install-istio:
	@echo "Downloading Istio..."
	@if [ ! -d "istio-1.28.2" ]; then \
		curl -L https://istio.io/downloadIstio | sh -; \
	else \
		echo "Istio already downloaded"; \
	fi
	@echo ""
	@echo "Installing Istio with demo profile..."
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl install --set profile=demo -y
	@echo ""
	@echo "Waiting for Istio pods to be ready..."
	@kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
	@echo ""
	@echo "✅ Istio installed successfully!"
	@echo ""
	@echo "Istio components:"
	@kubectl get pods -n istio-system

# Install Istio observability addons (Prometheus, Grafana, Kiali, Jaeger)
install-addons:
	@echo "Installing Istio observability addons..."
	@kubectl apply -f istio-*/samples/addons/prometheus.yaml
	@kubectl apply -f istio-*/samples/addons/grafana.yaml
	@kubectl apply -f istio-*/samples/addons/kiali.yaml
	@kubectl apply -f istio-*/samples/addons/jaeger.yaml
	@echo ""
	@echo "Waiting for addon pods to be ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n istio-system --timeout=120s || true
	@kubectl wait --for=condition=ready pod -l app=grafana -n istio-system --timeout=120s || true
	@kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=120s || true
	@kubectl wait --for=condition=ready pod -l app=jaeger -n istio-system --timeout=120s || true
	@echo ""
	@echo "✅ Observability addons installed successfully!"
	@echo ""
	@echo "Addon pods:"
	@kubectl get pods -n istio-system | grep -E 'prometheus|grafana|kiali|jaeger'

# Complete setup
setup: verify-all install-istio install-addons
	@echo ""
	@echo "✅ Setup complete! You're ready to run 'make dev'"

# Development commands
dev:
	@echo "Starting Skaffold in dev mode..."
	@echo "Press Ctrl+C to stop"
	skaffold dev

run:
	skaffold run

build:
	skaffold build

deploy:
	skaffold deploy

# Testing
test:
	@echo "Testing API endpoints..."
	@echo ""
	@echo "1️⃣  Testing GET /"
	@curl -s http://localhost:8080/ | jq '.' || curl http://localhost:8080/
	@echo ""
	@echo "2️⃣  Testing GET /health"
	@curl -s http://localhost:8080/health | jq '.' || curl http://localhost:8080/health
	@echo ""
	@echo "3️⃣  Testing GET /api"
	@curl -s http://localhost:8080/api | jq '.' || curl http://localhost:8080/api
	@echo ""
	@echo "4️⃣  Testing POST /api"
	@curl -s -X POST http://localhost:8080/api \
		-H "Content-Type: application/json" \
		-d '{"name": "Test", "message": "Hello from Makefile"}' | jq '.' || \
		curl -X POST http://localhost:8080/api \
		-H "Content-Type: application/json" \
		-d '{"name": "Test", "message": "Hello from Makefile"}'
	@echo ""
	@echo "✅ All tests completed!"

traffic:
	@echo "Generating test traffic (100 requests)..."
	@for i in $$(seq 1 100); do \
		curl -s http://localhost:8080/ > /dev/null; \
		curl -s http://localhost:8080/health > /dev/null; \
		curl -s http://localhost:8080/api > /dev/null; \
		echo -n "."; \
		sleep 0.1; \
	done
	@echo ""
	@echo "✅ Traffic generation complete! Open Kiali to view: make dashboard-kiali"

traffic-load:
	@echo "Generating high load (1000 requests)..."
	@for i in $$(seq 1 1000); do \
		curl -s http://localhost:8080/ > /dev/null & \
		curl -s http://localhost:8080/health > /dev/null & \
		curl -s http://localhost:8080/api > /dev/null & \
		if [ $$(($${i} % 100)) -eq 0 ]; then echo "$$i requests sent..."; fi; \
		sleep 0.01; \
	done
	@wait
	@echo "✅ Load test complete! Check dashboards for metrics."

# Observability Dashboards
dashboard-kiali:
	@echo "Opening Kiali dashboard..."
	@echo "View service mesh topology and traffic flow"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl dashboard kiali

dashboard-grafana:
	@echo "Opening Grafana dashboard..."
	@echo "View metrics and performance dashboards"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl dashboard grafana

dashboard-jaeger:
	@echo "Opening Jaeger dashboard..."
	@echo "View distributed tracing"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl dashboard jaeger

dashboard-prometheus:
	@echo "Opening Prometheus dashboard..."
	@echo "Query raw metrics"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl dashboard prometheus

dashboards:
	@echo "Opening all dashboards..."
	@echo "This will open 4 browser windows/tabs"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && \
		(istioctl dashboard kiali > /dev/null 2>&1 &) && \
		(istioctl dashboard grafana > /dev/null 2>&1 &) && \
		(istioctl dashboard jaeger > /dev/null 2>&1 &) && \
		(istioctl dashboard prometheus > /dev/null 2>&1 &)
	@echo "✅ All dashboards opened!"

# Status and debugging
status:
	@echo "📊 Kubernetes Resources Status"
	@echo ""
	@echo "Pods:"
	@kubectl get pods
	@echo ""
	@echo "Services:"
	@kubectl get services
	@echo ""
	@echo "Deployments:"
	@kubectl get deployments
	@echo ""
	@echo "Istio Gateway:"
	@kubectl get gateway
	@echo ""
	@echo "Istio VirtualService:"
	@kubectl get virtualservice
	@echo ""
	@echo "Istio DestinationRule:"
	@kubectl get destinationrule

logs:
	@echo "Streaming application logs..."
	@echo "Press Ctrl+C to stop"
	@POD=$$(kubectl get pod -l app=my-go-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD" ]; then \
		kubectl logs -f $$POD -c my-go-app; \
	else \
		echo "❌ No pods found. Is the application running? Try 'make dev'"; \
	fi

istio-status:
	@echo "📊 Istio System Status"
	@echo ""
	@echo "Istio Pods:"
	@kubectl get pods -n istio-system
	@echo ""
	@echo "Istio Services:"
	@kubectl get services -n istio-system
	@echo ""
	@echo "Istio Version:"
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl version

istio-analyze:
	@echo "Analyzing Istio configuration..."
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl analyze
	@echo "✅ Analysis complete"

# Cleanup
clean:
	@echo "Cleaning up application resources..."
	skaffold delete || kubectl delete -f k8s/ || true
	@echo "✅ Application resources cleaned up"

clean-all: clean
	@echo "Uninstalling Istio..."
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl uninstall --purge -y || true
	@kubectl delete namespace istio-system || true
	@echo "✅ Istio uninstalled"
	@echo ""
	@echo "To delete the cluster:"
	@echo "  minikube delete"
	@echo "  kind delete cluster --name skaffold-demo"
