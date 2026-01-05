# Demo Presentation Script: Skaffold Hot Reload in Kubernetes

## Introduction (2 minutes)

> "Today I'm going to show you how to achieve **3-5 second feedback loops** when developing applications in Kubernetes. We'll go from the traditional 2-5 minute build-deploy-test cycle to near-instant hot reloading using **Skaffold**."

**What is Skaffold?**
- Command-line tool from Google for Kubernetes development
- Automates build, deploy, and update workflows
- **Core feature: Lightning-fast hot reload in Kubernetes**
- Think of it as "live reload for Kubernetes"

**Key Pain Point We're Solving:**
The traditional Kubernetes development cycle is **painfully slow**:
- Edit code → Build Docker image → Push image → Update deployment → Wait for pod → Test
- **2-5 minutes per iteration** kills productivity and flow state

**What We'll Demo:**
- A Go HTTP server running in Kubernetes
- **Hot reload that updates your code in 3-5 seconds**
- How Skaffold and Air work together to make this possible
- Real-world development workflow

---

## Part 1: The Problem - Traditional Kubernetes Development (3 minutes)

> "First, let me show you what Kubernetes development typically looks like WITHOUT hot reload."

### Traditional Workflow

```bash
# Step 1: Build the Docker image
docker build -t my-app:v1 .
# ⏱️  Time: ~30-60 seconds

# Step 2: Push to registry (or load into cluster)
docker push my-app:v1  # or: minikube image load my-app:v1
# ⏱️  Time: ~30-60 seconds

# Step 3: Update deployment with new image
kubectl set image deployment/my-app my-app=my-app:v1
# or: kubectl apply -f k8s/
# ⏱️  Time: ~10 seconds

# Step 4: Wait for pod to restart
kubectl rollout status deployment/my-app
# ⏱️  Time: ~20-40 seconds

# Step 5: Port forward to access it
kubectl port-forward svc/my-service 8080:80

# Step 6: Test your change
curl http://localhost:8080

# Found a bug? START OVER from step 1!
```

### The Pain Points

- **2-5 minute cycle time** for each code change
- **5+ commands** across multiple terminals
- Easy to forget steps or use wrong image tags
- Context switching destroys flow state
- No automatic log streaming
- Manual cleanup required

**Total productivity cost: You spend more time waiting than coding.**

---

## Part 2: The Solution - Skaffold Overview (3 minutes)

> "Now watch what happens with Skaffold. Everything reduces to ONE command, and code changes appear in seconds."

### The Skaffold Way

```bash
# One command to start development
skaffold dev
```

**What happens automatically:**
1. ✅ Builds the Docker image
2. ✅ Deploys all Kubernetes manifests
3. ✅ Sets up automatic port forwarding to localhost:8080
4. ✅ Streams logs from all pods in real-time
5. ✅ **Watches files and hot-reloads on changes**
6. ✅ Cleans up everything when you press Ctrl+C

### Show the Configuration

```bash
cat skaffold.yaml
```

**Key section - File Sync:**
```yaml
build:
  artifacts:
    - image: my-go-app
      sync:  # ← This enables hot reload
        manual:
          - src: "**/*.go"      # Watch Go files on your laptop
            dest: /app          # Sync them to /app in container

portForward:  # ← Automatic port forwarding
  - resourceType: service
    resourceName: istio-ingressgateway
    namespace: istio-system
    port: 80
    localPort: 8080
```

---

## Part 3: Hot Reload Deep Dive - How It Actually Works (6 minutes)

> "Let me explain exactly how the hot reload magic happens. It involves TWO watchers working together: Skaffold on your laptop and Air inside the container."

### The Two-Watcher Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ YOUR LAPTOP (Host Machine)                                  │
│                                                              │
│  1. You edit main.go                                        │
│         ↓                                                    │
│  2. Skaffold watches files and detects change               │
│         ↓                                                    │
│  3. Skaffold syncs/copies file to container                 │
│                                                              │
└──────────────────────────────┬──────────────────────────────┘
                               │ File copied via Kubernetes API
                               ↓
┌─────────────────────────────────────────────────────────────┐
│ KUBERNETES POD (Container)                                  │
│                                                              │
│  4. Air is running and watching /app directory              │
│         ↓                                                    │
│  5. Air detects the new file Skaffold just synced           │
│         ↓                                                    │
│  6. Air runs: go build -o ./tmp/main .                      │
│         ↓                                                    │
│  7. Air kills old process and starts new binary             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### Component 1: Skaffold (Runs on your laptop)

**Configuration** (`skaffold.yaml`):
```yaml
sync:
  manual:
    - src: "**/*.go"      # Watch these patterns
      dest: /app          # Copy to this location in container
    - src: "go.mod"
      dest: /app
    - src: "go.sum"
      dest: /app
```

**What it does:**
- Watches your local filesystem for file changes
- When a `.go` file changes, copies it directly into the running container
- Uses Kubernetes API to sync files (no Docker rebuild!)
- **Speed: Near-instant file copy** (< 1 second)

#### Component 2: Air (Runs inside the container)

**Container entrypoint** (`Dockerfile`):
```dockerfile
# Air is installed in the container
RUN go install github.com/air-verse/air@v1.52.3

# Air runs as the main process
CMD ["air", "-c", ".air.toml"]
```

**Air configuration** (`.air.toml`):
```toml
[build]
  cmd = "go build -o ./tmp/main ."     # Build command
  delay = 1000                          # Wait 1s before building
  include_ext = ["go", "tpl", "tmpl", "html"]  # Watch these extensions
```

**What it does:**
- Runs continuously inside the container, watching the `/app` directory
- When it detects a file change (from Skaffold), triggers a rebuild
- Compiles the Go code: `go build -o ./tmp/main .`
- Kills the old process and starts the new binary
- **Speed: Go compilation + restart** (~2-4 seconds)

### The Complete Flow

Here's what happens when you save `main.go`:

```
┌──────────────────────┐
│ 1. EDIT             │  You: Save main.go in your editor
│    main.go          │  Time: 0s
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 2. DETECT           │  Skaffold: Detects file change via filesystem watch
│    (Skaffold)       │  Time: < 100ms
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 3. SYNC             │  Skaffold: Copies main.go → container:/app/main.go
│    (Skaffold)       │  Time: ~500ms
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 4. DETECT           │  Air: Detects new file in /app
│    (Air)            │  Time: < 100ms
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 5. BUILD            │  Air: Runs `go build -o ./tmp/main .`
│    (Air)            │  Time: ~1-2s
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 6. RESTART          │  Air: Kills old process, starts new binary
│    (Air)            │  Time: ~100ms
└──────────┬───────────┘
           │
           ↓
┌──────────────────────┐
│ 7. LIVE!            │  Your changes are live!
│                     │  Total time: ~3-5 seconds
└─────────────────────┘
```

### Why This Two-Stage Approach?

**Q: Why not just have Skaffold rebuild the entire Docker image?**

**A: Speed!**

| Method | Time | What Happens |
|--------|------|--------------|
| **Full rebuild** | 30-60s | Rebuild entire Docker image → Push → Redeploy pod |
| **File sync + Air** | 3-5s | Copy file → Recompile Go code → Restart process |

**The file sync approach is 10-20x faster** because it:
- Skips Docker image building
- Skips image registry push
- Skips pod restart
- Only recompiles the changed code

### What If You Remove Air?

Without Air, here's what would happen:
- ✅ Skaffold would **still sync files** to the container
- ❌ But **nothing would rebuild or restart** the app
- ❌ The new `.go` files would sit there unused
- ❌ You'd need to manually restart or use a different hot-reload tool

**Air is the critical piece that makes the synced files actually take effect.**

---

## Part 4: Demo - Hot Reload in Action (5 minutes)

> "Now let's see this in action. Watch how fast we can iterate."

### Step 1: Start Skaffold

```bash
# Start development mode
make dev
# or: skaffold dev
```

**Watch the terminal output:**
```
Generating tags...
 - my-go-app -> my-go-app:latest
Checking cache...
 - my-go-app: Not found. Building
Building [my-go-app]...
...
Tags used in deployment:
 - my-go-app -> my-go-app:abc123
Starting deploy...
 - deployment.apps/my-go-app created
 - service/my-go-app-service created
Port forwarding service/istio-ingressgateway in namespace istio-system...
Watching for changes...
[my-go-app] Running air...
```

### Step 2: Test the Application

```bash
# In a new terminal
curl http://localhost:8080/
```

**Response:**
```json
{
  "message": "Hello from Kubernetes with Skaffold!",
  "timestamp": "2026-01-04T10:30:00Z"
}
```

### Step 3: Make a Code Change

**Open `main.go` and edit the message:**

```go
func helloHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    response := MessageResponse{
        Message:   "🚀 LIVE UPDATE! Hot reload is working!", // ← Change this line
        Timestamp: time.Now(),
    }
    json.NewEncoder(w).Encode(response)
}
```

**Save the file** (Ctrl+S or Cmd+S)

### Step 4: Watch the Skaffold Terminal

```
Syncing 1 files for my-go-app:latest
Copying files: map[main.go:[/app]] to my-go-app-7d4b8c9f5-xk2p9
[my-go-app] building...
[my-go-app] running...
Watching for changes...
```

**Time elapsed: ~3-5 seconds**

### Step 5: Test Immediately

```bash
curl http://localhost:8080/
```

**Response:**
```json
{
  "message": "🚀 LIVE UPDATE! Hot reload is working!",
  "timestamp": "2026-01-04T10:30:05Z"
}
```

**✅ Your change is LIVE! From save to working code in under 5 seconds.**

### Step 6: Make More Changes

Try a few more rapid iterations:

1. **Change the health check response**
2. **Add a new field to the JSON response**
3. **Modify the API endpoint logic**

Each change takes **3-5 seconds** to go live.

**Point out:**
- No manual commands needed
- Logs stream automatically
- Port forwarding stays active
- Each iteration is lightning fast

---

## Part 5: Why Hot Reload Changes Everything (4 minutes)

### Productivity Comparison

#### Traditional Workflow
```
Edit → Build (60s) → Push (30s) → Deploy (20s) → Test (10s) = ~2 min
Edit → Build (60s) → Push (30s) → Deploy (20s) → Test (10s) = ~2 min
Edit → Build (60s) → Push (30s) → Deploy (20s) → Test (10s) = ~2 min

Total for 3 iterations: ~6 minutes
```

#### Skaffold Hot Reload
```
Edit → Sync + Rebuild (5s) → Test (1s) = ~6s
Edit → Sync + Rebuild (5s) → Test (1s) = ~6s
Edit → Sync + Rebuild (5s) → Test (1s) = ~6s

Total for 3 iterations: ~18 seconds
```

**Result: 20x faster! And you can make 20 iterations in the time it took to make 1.**

### Real-World Impact

#### 1. **Maintain Flow State**
- No waiting = no context switching
- Stay focused on solving problems
- Don't lose your train of thought

#### 2. **Faster Experimentation**
- Try ideas quickly without penalty
- A/B test different approaches
- Iterate on UI/UX rapidly

#### 3. **Better Debugging**
- Add logging statements and see results instantly
- Test fixes immediately
- Narrow down issues faster

#### 4. **Production Parity**
- Developing in **real Kubernetes**
- Same environment as staging/production
- Catch deployment issues early
- Test with real service mesh (Istio), load balancers, etc.

### When Hot Reload Works Best

**Perfect for:**
- ✅ **Interpreted languages**: Go, Node.js, Python, Ruby (with language-specific watchers)
- ✅ **Microservices development**: Test service interactions in real-time
- ✅ **Frontend development**: React, Vue, Angular with webpack dev server
- ✅ **Configuration changes**: Update ConfigMaps, environment variables

**Limitations:**
- ⚠️ **Binary changes**: Changing `Dockerfile` still requires full rebuild
- ⚠️ **Dependency changes**: Adding new packages may require rebuild
- ⚠️ **Init logic**: Changes to startup code may not reflect until pod restart

---

## Part 6: Real-World Scenario (4 minutes)

> "Let's walk through a realistic debugging scenario to see the power of hot reload."

### Scenario: Bug Report

**Issue:** "The API endpoint returns a 200 OK even when the JSON payload is invalid. It should return 400 Bad Request."

### Traditional Debugging (Without Hot Reload)

```
1. Read the bug report                          (30s)
2. Find the relevant code                       (1 min)
3. Make a fix                                   (30s)
4. Build Docker image                           (60s)
5. Push to registry                             (30s)
6. Update deployment                            (20s)
7. Wait for pod restart                         (30s)
8. Test the fix                                 (20s)
9. Realize you made a typo                      (10s)
10. REPEAT steps 3-8...                         (3 min)
11. Test again - still broken                   (20s)
12. Fix again                                   (30s)
13. REPEAT steps 4-8...                         (3 min)
14. Finally working!

Total time: ~12-15 minutes (3 test iterations)
```

### With Skaffold Hot Reload

```bash
# Skaffold already running: make dev
```

```
1. Read the bug report                          (30s)
2. Find the relevant code                       (1 min)
3. Make a fix in main.go                        (30s)
4. Save → Auto-reload                           (5s)
5. Test the fix                                 (10s)
6. Realize you made a typo                      (5s)
7. Fix typo                                     (10s)
8. Save → Auto-reload                           (5s)
9. Test again - still need adjustment           (10s)
10. Adjust the logic                            (20s)
11. Save → Auto-reload                          (5s)
12. Test - working!                             (10s)

Total time: ~4 minutes (3 test iterations)
```

**Result: 3x faster, and that gap widens with more iterations!**

### Demonstrate It

**Current code** (buggy):
```go
func apiHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method == http.MethodPost {
        var data map[string]interface{}
        if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
            // BUG: Should return 400, but currently returns 200
            json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid JSON"})
            return
        }
        // ...
    }
}
```

**Test the bug:**
```bash
curl -X POST http://localhost:8080/api \
  -H "Content-Type: application/json" \
  -d 'invalid-json' \
  -w "\nStatus: %{http_code}\n"

# Output: Status: 200 ← BUG! Should be 400
```

**Fix it:**
```go
func apiHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method == http.MethodPost {
        var data map[string]interface{}
        if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
            w.WriteHeader(http.StatusBadRequest)  // ← ADD THIS LINE
            json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid JSON"})
            return
        }
        // ...
    }
}
```

**Save → Wait 5 seconds → Test again:**
```bash
curl -X POST http://localhost:8080/api \
  -H "Content-Type: application/json" \
  -d 'invalid-json' \
  -w "\nStatus: %{http_code}\n"

# Output: Status: 400 ← FIXED!
```

**From bug to fix in under 1 minute of actual testing time.**

---

## Part 7: Additional Skaffold Features (3 minutes)

### 1. Automatic Log Streaming

No need to run `kubectl logs -f <pod-name>`:

```bash
# Skaffold automatically streams logs from all containers
# They appear in the same terminal where you ran `skaffold dev`
```

**Benefits:**
- Automatically follows new pods
- Color-coded output for multiple containers
- Filters to relevant logs only
- No need to find pod names manually

### 2. Automatic Cleanup

```bash
# Press Ctrl+C in the Skaffold terminal
```

**Watch what happens:**
- Skaffold deletes all deployed resources
- Port forwarding stops
- Cluster returns to clean state
- No orphaned pods or services

**Restart anytime:**
```bash
make dev  # Everything comes back up automatically
```

### 3. Works with Multiple Services

Skaffold can manage multiple microservices:

```yaml
build:
  artifacts:
    - image: frontend
      context: ./frontend
      sync:
        manual:
          - src: "src/**/*.js"
            dest: /app/src
    - image: backend
      context: ./backend
      sync:
        manual:
          - src: "**/*.go"
            dest: /app
    - image: worker
      context: ./worker
```

All services get hot reload, unified logging, and coordinated deployment.

---

## Part 8: Getting Started with Hot Reload (2 minutes)

### Prerequisites

```bash
# Install Skaffold
brew install skaffold  # macOS
# or: curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64

# Verify installation
skaffold version
```

### Add Hot Reload to Your Project

#### 1. Create `skaffold.yaml`

```yaml
apiVersion: skaffold/v4beta6
kind: Config
build:
  artifacts:
    - image: your-app
      sync:
        manual:
          - src: "**/*.go"       # Adjust for your language
            dest: /app
manifests:
  rawYaml:
    - k8s/*.yaml

portForward:
  - resourceType: service
    resourceName: your-service
    port: 80
    localPort: 8080
```

#### 2. Add a Hot Reload Tool to Your Container

For **Go** (use Air):
```dockerfile
RUN go install github.com/air-verse/air@latest
CMD ["air", "-c", ".air.toml"]
```

For **Node.js** (use nodemon):
```dockerfile
RUN npm install -g nodemon
CMD ["nodemon", "index.js"]
```

For **Python** (use watchdog):
```dockerfile
RUN pip install watchdog
CMD ["watchmedo", "auto-restart", "-p", "*.py", "python", "app.py"]
```

#### 3. Start Developing

```bash
skaffold dev
```

**That's it! Hot reload is now enabled.**

---

## Bonus: Kiali and Observability (5 minutes)

> "Beyond hot reload, this project includes Istio service mesh with full observability. This is optional but powerful for production-like development."

### What is Kiali?

Kiali is a web-based dashboard that visualizes your service mesh in real-time.

**Features:**
- Service topology graph
- Traffic flow visualization
- Request rates, error rates, latencies
- Configuration validation
- Health indicators

### Open Kiali

```bash
# Make sure Istio and observability addons are installed
make install-addons

# Open Kiali dashboard
make dashboard-kiali
# or: istioctl dashboard kiali
```

### Generate Traffic to Visualize

```bash
# In another terminal, generate some traffic
for i in {1..100}; do
  curl http://localhost:8080/
  curl http://localhost:8080/health
  curl http://localhost:8080/api
  sleep 0.1
done
```

### What You'll See in Kiali

1. **Graph View**
   - Visual representation of your services
   - Traffic flowing from ingress → service → pod
   - Color-coded health indicators (green = healthy, red = errors)

2. **Service Details**
   - Request volume (requests per second)
   - Success rate (percentage of successful requests)
   - Response times (P50, P95, P99)

3. **Istio Configuration**
   - Gateway, VirtualService, DestinationRule configs
   - Validation warnings if misconfigured

4. **Distributed Tracing**
   - Click on a request to see full trace
   - See latency breakdown by service
   - Identify performance bottlenecks

### Why This Matters for Development

**Production Parity:**
- See exactly how traffic flows in production
- Test circuit breakers and retries locally
- Validate Istio configurations before deploying
- Debug routing issues visually

**Learning Opportunity:**
- Learn production tools in safe environment
- Understand service mesh concepts hands-on
- Practice with observability dashboards

### Other Observability Tools

```bash
# Grafana - Metrics and dashboards
make dashboard-grafana

# Prometheus - Raw metrics
make dashboard-prometheus

# Jaeger - Distributed tracing
make dashboard-jaeger
```

### The Connection to Hot Reload

**With Skaffold + Istio + Hot Reload, you get:**

1. Edit your code
2. See changes live in 5 seconds
3. Watch traffic flow in Kiali in real-time
4. See metrics update immediately in Grafana
5. Trace requests through Jaeger

**This is a production-grade development environment on your laptop!**

---

## Conclusion

### What We Learned

1. ✅ **Hot reload is possible in Kubernetes** using Skaffold + file watchers (Air, nodemon, etc.)
2. ✅ **3-5 second feedback loops** vs 2-5 minute traditional workflow
3. ✅ **Two-watcher architecture**: Skaffold syncs files, Air rebuilds inside container
4. ✅ **Production parity**: Develop in real Kubernetes with real service mesh
5. ✅ **Bonus: Full observability** with Kiali, Grafana, Prometheus, Jaeger

### Key Takeaways

**Speed:**
- 10-60x faster iteration cycles
- More iterations = better code

**Developer Experience:**
- One command: `skaffold dev`
- Automatic port forwarding, logging, cleanup
- Stay in flow state

**Production Confidence:**
- Test in real Kubernetes
- Catch issues early
- Same configs as production

### Getting Started

```bash
# Clone this project
git clone <repo>

# Start developing
make dev

# Make changes to main.go and watch them go live in 5 seconds!
```

### Resources

- **Skaffold Docs:** https://skaffold.dev
- **Air (Go hot reload):** https://github.com/air-verse/air
- **This Project's README:** Complete setup guide
- **Makefile:** All commands documented

---

## Q&A Talking Points

**Q: "Does hot reload work for all languages?"**
A: File sync works for any language. You just need a watcher in your container:
- **Go:** Air
- **Node.js:** nodemon
- **Python:** watchdog, uvicorn --reload
- **Java:** Spring DevTools
- **Ruby:** rerun

**Q: "What if I change the Dockerfile or add dependencies?"**
A: Those require a full rebuild. Stop Skaffold (Ctrl+C) and restart `skaffold dev`. It will rebuild the image. File sync is for source code changes only.

**Q: "Can I use this in CI/CD?"**
A: Yes! Use `skaffold build --push` for CI/CD. Hot reload is for local development only.

**Q: "How does this compare to Docker Compose?"**
A: Docker Compose can do hot reload too, but Skaffold gives you **production parity** by using real Kubernetes. If you deploy to Kubernetes in production, develop in Kubernetes locally.

**Q: "What about resource usage?"**
A: You need a local Kubernetes cluster (Docker Desktop, minikube, kind). Skaffold itself is lightweight - it just orchestrates what you'd already be running.

**Q: "Does Skaffold require Air?"**
A: No! Air is optional. Skaffold handles file sync. You can use any hot-reload tool (nodemon, watchdog, etc.) or even no watcher at all (just file sync without auto-reload).

---

## Demo Checklist

**Before presenting:**
- [ ] Kubernetes cluster running (`kubectl cluster-info`)
- [ ] Skaffold installed (`skaffold version`)
- [ ] Test `make dev` works end-to-end
- [ ] Have `main.go` open in editor
- [ ] Prepare a simple code change to demonstrate
- [ ] Terminal layout: 2 terminals visible (Skaffold + curl tests)
- [ ] (Optional) Istio + Kiali installed for bonus section

**During demo:**
- [ ] Emphasize the **speed difference** (2-5 min → 5 sec)
- [ ] Show the **two-watcher diagram** clearly
- [ ] Make **live code changes** to demonstrate
- [ ] Point out **automatic features** (port forward, logs, cleanup)
- [ ] Keep it focused on **hot reload** (save Kiali for bonus)

--