package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version"`
}

type MessageResponse struct {
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Version:   "1.0.0",
	}
	json.NewEncoder(w).Encode(response)
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	response := MessageResponse{
		Message:   "Hello from Go + Kubernetes + Skaffold with Air hot reload!",
		Timestamp: time.Now(),
	}
	json.NewEncoder(w).Encode(response)
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case "GET":
		response := MessageResponse{
			Message:   "API endpoint is working",
			Timestamp: time.Now(),
		}
		json.NewEncoder(w).Encode(response)
	case "POST":
		var data map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&data); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(ErrorResponse{Error: "Invalid JSON"})
			return
		}
		response := map[string]interface{}{
			"received":  data,
			"timestamp": time.Now(),
		}
		json.NewEncoder(w).Encode(response)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(ErrorResponse{Error: "Method not allowed"})
	}
}

func main() {
	http.HandleFunc("/", helloHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/api", apiHandler)

	port := "8080"
	fmt.Printf("Server starting on port %s...\n", port)
	fmt.Println("Available endpoints:")
	fmt.Println("  GET  /          - Hello message")
	fmt.Println("  GET  /health    - Health check")
	fmt.Println("  GET  /api       - API test")
	fmt.Println("  POST /api       - Echo JSON data")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
