package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/gorilla/mux"
	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/rs/cors"
)

type DeviceData struct {
	DeviceID   string                 `json:"device_id"`
	DeviceType string                 `json:"device_type"`
	Timestamp  int64                  `json:"timestamp"`
	Data       map[string]interface{} `json:"data"`
}

var (
	db          *sql.DB
	redisClient *redis.Client
)

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Println("Error loading .env file")
	}

	// Initialize PostgreSQL connection
	dbURL := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		os.Getenv("DB_HOST"), os.Getenv("DB_PORT"), os.Getenv("DB_USER"), os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))

	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		log.Fatalf("Error connecting to database: %v", err)
	}

	// Initialize Redis connection
	redisClient = redis.NewClient(&redis.Options{
		Addr:     os.Getenv("REDIS_ADDR"),
		Password: os.Getenv("REDIS_PASSWORD"),
		DB:       0, // use default DB
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		log.Fatalf("Error connecting to Redis: %v", err)
	}

	r := mux.NewRouter()
	r.HandleFunc("/iot-data", handleIoTData).Methods("GET", "POST")

	// Create a new CORS handler
	c := cors.New(cors.Options{
		AllowedOrigins: []string{"http://localhost:3000"}, // Allow requests from your Next.js app
		AllowedMethods: []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders: []string{"Content-Type", "Authorization"},
	})

	// Wrap your router with the CORS handler
	handler := c.Handler(r)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Server starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, handler))
}

func handleIoTData(w http.ResponseWriter, r *http.Request) {
	log.Printf("Received request on /iot-data. Method: %s, Content-Type: %s", r.Method, r.Header.Get("Content-Type"))

	switch r.Method {
	case "GET":
		handleGetIoTData(w, r)
	case "POST":
		handlePostIoTData(w, r)
	}
}

func handleGetIoTData(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Get all keys from Redis
	keys, err := redisClient.Keys(ctx, "*").Result()
	if err != nil {
		log.Printf("Error getting keys from Redis: %v", err)
		http.Error(w, "Error retrieving device data", http.StatusInternalServerError)
		return
	}

	var allDeviceData []DeviceData

	// Fetch data for each key
	for _, key := range keys {
		val, err := redisClient.Get(ctx, key).Result()
		if err != nil {
			log.Printf("Error getting data for key %s from Redis: %v", key, err)
			continue
		}

		var deviceData DeviceData
		err = json.Unmarshal([]byte(val), &deviceData)
		if err != nil {
			log.Printf("Error unmarshaling data for key %s: %v", key, err)
			continue
		}

		allDeviceData = append(allDeviceData, deviceData)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allDeviceData)
}

func handlePostIoTData(w http.ResponseWriter, r *http.Request) {
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Printf("Error reading request body: %v", err)
		http.Error(w, "Error reading request body", http.StatusBadRequest)
		return
	}
	log.Printf("Received body: %s", string(body))

	var deviceData DeviceData
	err = json.Unmarshal(body, &deviceData)
	if err != nil {
		log.Printf("Error unmarshaling JSON: %v", err)
		http.Error(w, "Invalid JSON format", http.StatusBadRequest)
		return
	}

	log.Printf("Parsed DeviceData: %+v", deviceData)

	dataJSON, err := json.Marshal(deviceData.Data)
	if err != nil {
		log.Printf("Error marshaling Data to JSON: %v", err)
		http.Error(w, "Error processing data", http.StatusInternalServerError)
		return
	}

	// Insert into database
	_, err = db.Exec(`
		INSERT INTO device_data (device_id, device_type, timestamp, data)
		VALUES ($1, $2, $3, $4)
	`, deviceData.DeviceID, deviceData.DeviceType, deviceData.Timestamp, dataJSON)
	if err != nil {
		log.Printf("Error inserting data into database: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Cache the latest data in Redis
	ctx := context.Background()
	err = redisClient.Set(ctx, deviceData.DeviceID, string(body), 1*time.Hour).Err()
	if err != nil {
		log.Printf("Error caching data in Redis: %v", err)
		// Continue execution even if Redis caching fails
	}

	log.Println("Data processed, inserted into database, and cached in Redis successfully")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Data received, stored, and cached"})
}
