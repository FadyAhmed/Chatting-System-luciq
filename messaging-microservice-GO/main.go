package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
	"github.com/streadway/amqp"

	"github.com/google/uuid"
)

type Message struct {
	ChatID        string   `json:"chat_id"`
	Content       string   `json:"content"`
	SenderUserID  string   `json:"user_id"`
	ApplicationId string   `json:"application_id"`
	Subscribers   []string `json:"subscribers"`
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type SubscribeRequest struct {
	UserID string `json:"user_id" binding:"required"`
	ChatID string `json:"chat_id"`
}

type RedisClient interface {
	SAdd(key string, members ...interface{}) error
	SIsMember(key string, member interface{}) (bool, error)
	Close() error
}

type RealRedisClient struct {
	client *redis.Client
}

func ConnectRedis(redisURL string) (RedisClient, error) {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse redis URL: %w", err)
	}

	client := redis.NewClient(opts)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if _, err := client.Ping(ctx).Result(); err != nil {
		return nil, fmt.Errorf("failed to connect or ping redis at %s: %w", redisURL, err)
	}

	fmt.Printf("--- Real Redis Connection Established at %s.\n", redisURL)
	return &RealRedisClient{client: client}, nil
}

func (r *RealRedisClient) SAdd(key string, members ...interface{}) error {
	ctx := context.Background()
	return r.client.SAdd(ctx, key, members...).Err()
}

func (r *RealRedisClient) SIsMember(key string, member interface{}) (bool, error) {
	ctx := context.Background()
	return r.client.SIsMember(ctx, key, member).Result()
}

func (r *RealRedisClient) Close() error {
	err := r.client.Close()
	if err == nil {
		fmt.Println("--- Real Redis Connection Closed Successfully.")
	}
	return err
}

type MQConfig struct {
	URL       string
	QueueName string
}

type MQClient interface {
	Publish(exchange, key string, mandatory, immediate bool, body []byte) error
	Close() error
}

type RealMQClient struct {
	conn *amqp.Connection
	ch   *amqp.Channel
	MQConfig
}

func (r *RealMQClient) Publish(exchange, key string, mandatory, immediate bool, body []byte) error {
	return r.ch.Publish(
		"",
		r.QueueName,
		mandatory,
		immediate,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	)
}

func (r *RealMQClient) Close() error {
	var err error
	if r.ch != nil {
		if chErr := r.ch.Close(); chErr != nil {
			err = fmt.Errorf("error closing channel: %w", chErr)
		}
	}
	if r.conn != nil {
		if connErr := r.conn.Close(); connErr != nil {
			if err != nil {
				err = fmt.Errorf("%v; error closing connection: %w", err, connErr)
			} else {
				err = fmt.Errorf("error closing connection: %w", connErr)
			}
		}
	}

	if err == nil {
		fmt.Println("--- RabbitMQ Connection Closed Successfully.")
	}
	return err
}

type Server struct {
	userConnections map[string]*websocket.Conn
	mu              sync.RWMutex
	mqClient        MQClient
	mqConfig        MQConfig
	redisClient     RedisClient
}

func ConnectMQ(cfg MQConfig) (MQClient, error) {
	fmt.Printf("--- Connecting to RabbitMQ at %s...\n", cfg.URL)

	conn, err := amqp.Dial(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("amqp.Dial failed: %w", err)
	}

	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("channel creation failed: %w", err)
	}

	_, err = ch.QueueDeclare(
		cfg.QueueName,
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		ch.Close()
		conn.Close()
		return nil, fmt.Errorf("queue declare failed for %s: %w", cfg.QueueName, err)
	}

	fmt.Printf("--- RabbitMQ Connection Established and Queue '%s' declared.\n", cfg.QueueName)
	return &RealMQClient{conn: conn, ch: ch, MQConfig: cfg}, nil
}

func NewServer() *Server {
	// 1. Read RabbitMQ URL from ENV or use default
	mqURL := os.Getenv("RABBITMQ_URL")
	if mqURL == "" {
		fmt.Printf("INFO: RABBITMQ_URL not set. Using default: %s\n", mqURL)
	}

	mqConfig := MQConfig{
		URL: mqURL,
	}

	mqClient, err := ConnectMQ(mqConfig)
	if err != nil {
		panic(fmt.Sprintf("Failed to connect to RabbitMQ at %s: %v", mqURL, err))
	}

	// 2. Read Redis URL from ENV or use default
	redisURL := os.Getenv("REDIS_URL")
	if redisURL == "" {
		fmt.Printf("INFO: REDIS_URL not set. Using default: %s\n", redisURL)
	}

	redisClient, err := ConnectRedis(redisURL)
	if err != nil {
		panic(fmt.Sprintf("Failed to connect to Real Redis at %s: %v", redisURL, err))
	}

	return &Server{
		userConnections: make(map[string]*websocket.Conn),
		mqClient:        mqClient,
		mqConfig:        mqConfig,
		redisClient:     redisClient,
	}
}

func (s *Server) isUserSubscribed(userID, chatID string) bool {
	key := fmt.Sprintf("user:subscriptions:%s", userID)

	isMember, err := s.redisClient.SIsMember(key, chatID)
	if err != nil {
		fmt.Printf("[REDIS ERROR] Failed to check membership for user %s: %v\n", userID, err)
		return false
	}
	return isMember
}

func (s *Server) handleSubscribe(c *gin.Context) {
	var req SubscribeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.ChatID == "" {
		req.ChatID = uuid.NewString()
	}

	userKey := fmt.Sprintf("user:subscriptions:%s", req.UserID)

	if err := s.redisClient.SAdd(userKey, req.ChatID); err != nil {
		fmt.Printf("[REDIS ERROR] Failed to save subscription for user %s: %v\n", req.UserID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save subscription"})
		return
	}

	chatKey := fmt.Sprintf("chat:subscriptions:%s", req.ChatID)

	if err := s.redisClient.SAdd(chatKey, req.ChatID); err != nil {
		fmt.Printf("[REDIS ERROR] Failed to save subscription for chat %s: %v\n", req.UserID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save subscription"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": fmt.Sprintf("User %s subscribed to chat %s successfully.", req.UserID, req.ChatID),
		"chat_id": req.ChatID,
	})
}

func (s *Server) PublishToMQ(message []byte) error {
	return s.mqClient.Publish(
		"",
		s.mqConfig.QueueName,
		false, // mandatory
		false, // immediate
		message,
	)
}

func (s *Server) BroadcastToChat(chatID string, message []byte) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for userID, conn := range s.userConnections {
		if s.isUserSubscribed(userID, chatID) {
			go func(c *websocket.Conn, targetID string) {
				if err := c.WriteMessage(websocket.TextMessage, message); err != nil {
					fmt.Printf("Error sending message to user %s: %v\n", targetID, err)
				}
			}(conn, userID)
		}
	}
}

func (s *Server) handleWS(c *gin.Context) {
	userID := c.Query("userId")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing userId query parameter"})
		return
	}

	ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		fmt.Println("Failed to set websocket upgrade:", err)
		return
	}

	s.mu.Lock()
	if _, exists := s.userConnections[userID]; exists {
		fmt.Printf("User %s already connected. Closing new connection.\n", userID)
		s.mu.Unlock()
		ws.Close()
		return
	}
	s.userConnections[userID] = ws
	s.mu.Unlock()

	fmt.Printf("New Connection Started for Registered User: %s\n", userID)

	s.readLoop(ws, userID)

	s.mu.Lock()
	delete(s.userConnections, userID)
	s.mu.Unlock()

	ws.Close()
	fmt.Printf("Connection Closed and Cleaned Up for User: %s\n", userID)
}

func (s *Server) readLoop(ws *websocket.Conn, senderID string) {
	for {
		_, rawMsg, err := ws.ReadMessage()
		if err != nil {
			if websocket.IsCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) || err == io.EOF {
				break
			}
			fmt.Printf("Read Error from %s: %v\n", senderID, err)
			break
		}

		var incomingMsg Message
		if err := json.Unmarshal(rawMsg, &incomingMsg); err != nil {
			fmt.Printf("Error unmarshalling JSON from %s: %v\n", senderID, err)
			ws.WriteMessage(websocket.TextMessage, []byte(`{"error": "Invalid JSON format"}`))
			continue
		}

		incomingMsg.SenderUserID = senderID

		if incomingMsg.ChatID == "" {
			newUUID, uuidErr := uuid.NewRandom()
			if uuidErr != nil {
				fmt.Printf("Error generating UUID for new chat: %v\n", uuidErr)
				ws.WriteMessage(websocket.TextMessage, []byte(`{"error": "Failed to create new chat ID"}`))
				continue
			}
			incomingMsg.ChatID = newUUID.String()
			fmt.Printf("[%s] Starting new chat with dynamic ID: %s\n", senderID, incomingMsg.ChatID)
		}

		if len(incomingMsg.Subscribers) > 0 {
			chatID := incomingMsg.ChatID
			keyPrefix := "user:subscriptions:"

			subscribers := make(map[string]struct{})
			subscribers[senderID] = struct{}{} // Add sender

			for _, userID := range incomingMsg.Subscribers {
				subscribers[userID] = struct{}{}
			}

			for userID := range subscribers {
				key := fmt.Sprintf("%s%s", keyPrefix, userID)
				if err := s.redisClient.SAdd(key, chatID); err != nil {
					fmt.Printf("[REDIS ERROR] Failed to auto-subscribe user %s to chat %s: %v\n", userID, chatID, err)
				} else if userID != senderID {
					fmt.Printf("[AUTO-SUBSCRIBE] User %s subscribed to chat %s.\n", userID, chatID)
				}
			}
		}

		if !s.isUserSubscribed(senderID, incomingMsg.ChatID) {
			errMsg := fmt.Sprintf(`{"error": "Sender %s is not subscribed to chat %s. Message blocked."}`, senderID, incomingMsg.ChatID)
			fmt.Printf("SECURITY BLOCK: %s\n", errMsg)
			ws.WriteMessage(websocket.TextMessage, []byte(errMsg))
			continue
		}

		outgoingMsg, _ := json.Marshal(incomingMsg)

		go func(msgBytes []byte) {
			if err := s.PublishToMQ(msgBytes); err != nil {
				fmt.Printf("[MQ ERROR] Failed to publish message: %v\n", err)
			}
		}(outgoingMsg)

		if incomingMsg.ChatID != "" {
			fmt.Printf("[%s] Chat message routed to [%s] (Content: %s)\n", senderID, incomingMsg.ChatID, incomingMsg.Content)
			s.BroadcastToChat(incomingMsg.ChatID, outgoingMsg)
		} else {
			fmt.Printf("[%s] Message somehow bypassed ChatID check.\n", senderID)
			ws.WriteMessage(websocket.TextMessage, []byte(`{"error": "Internal server error: ChatID not resolved."}`))
		}
	}
}

func main() {
	server := NewServer()

	defer server.mqClient.Close()
	defer server.redisClient.Close()

	r := gin.Default()

	r.GET("/ws", server.handleWS)

	r.POST("/subscribe", server.handleSubscribe)

	fmt.Println("Gin chat server running on :8080")
	if err := r.Run(":8080"); err != nil {
		panic(err)
	}
}
