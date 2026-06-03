package delivery

import (
	"fmt"
	"time"
)

// ─── Platform Constants ───────────────────────────────────────────────────────

const (
	PlatformFoodpanda = "foodpanda"
	PlatformUberEats  = "uber_eats"
	PlatformMock      = "mock"
)

// ─── DTOs ─────────────────────────────────────────────────────────────────────

// IncomingOrder represents an order received from a delivery platform.
type IncomingOrder struct {
	PlatformOrderID  string
	Platform         string // "foodpanda", "uber_eats"
	CustomerName     string
	CustomerPhone    string
	DeliveryAddress  string
	Items            []IncomingOrderItem
	Subtotal         float64
	DeliveryFee      float64
	Total            float64
	EstimatedPickup  time.Time // when rider is expected to pick up
	Notes            string
	ReceivedAt       time.Time
}

// IncomingOrderItem is a single item line from the delivery platform.
type IncomingOrderItem struct {
	ExternalItemID string
	Name           string
	Quantity       int
	UnitPrice      float64
}

// OrderConfirmRequest is sent to the platform to accept an order.
type OrderConfirmRequest struct {
	PlatformOrderID  string
	EstimatedMinutes int // estimated preparation time in minutes
}

// OrderConfirmResponse is the platform's response to confirmation.
type OrderConfirmResponse struct {
	Success   bool
	Message   string
	ConfirmedAt time.Time
}

// OrderStatusUpdateRequest updates the platform on order progress.
type OrderStatusUpdateRequest struct {
	PlatformOrderID string
	Status          PlatformOrderStatus
}

// PlatformOrderStatus represents the delivery platform's order status.
type PlatformOrderStatus string

const (
	PlatformStatusAccepted  PlatformOrderStatus = "accepted"  // kitchen accepted
	PlatformStatusReady     PlatformOrderStatus = "ready"     // ready for pickup
	PlatformStatusPickedUp  PlatformOrderStatus = "picked_up" // rider collected
	PlatformStatusDelivered PlatformOrderStatus = "delivered"
	PlatformStatusCancelled PlatformOrderStatus = "cancelled"
)

// OrderStatusUpdateResponse is the platform's response to a status update.
type OrderStatusUpdateResponse struct {
	Success bool
	Message string
}

// ─── Interface ────────────────────────────────────────────────────────────────

// DeliveryPlatform defines the interface for delivery platform integrations.
// All platform clients (Foodpanda, Uber Eats, mock) must implement this.
type DeliveryPlatform interface {
	// Name returns the platform identifier (e.g. "foodpanda", "uber_eats").
	Name() string

	// ConfirmOrder accepts an incoming order and sends the estimated prep time.
	ConfirmOrder(req OrderConfirmRequest) (*OrderConfirmResponse, error)

	// UpdateOrderStatus notifies the platform of order progress.
	UpdateOrderStatus(req OrderStatusUpdateRequest) (*OrderStatusUpdateResponse, error)
}

// ─── Config ───────────────────────────────────────────────────────────────────

// Config holds delivery platform configuration.
type Config struct {
	MockMode       bool
	FoodpandaKey   string // API key from Foodpanda partner portal
	FoodpandaURL   string // Webhook base URL (provided by Foodpanda)
	UberEatsID     string // Client ID from Uber Eats Developer portal
	UberEatsSecret string // Client Secret
	UberEatsURL    string // Base URL (prod or sandbox)
}

// ─── Mock Client ──────────────────────────────────────────────────────────────

// MockDeliveryClient returns instant success without external API calls.
// Use when no real platform credentials are configured.
type MockDeliveryClient struct {
	platform string
}

func (m *MockDeliveryClient) Name() string { return m.platform }

func (m *MockDeliveryClient) ConfirmOrder(req OrderConfirmRequest) (*OrderConfirmResponse, error) {
	return &OrderConfirmResponse{
		Success:     true,
		Message:     fmt.Sprintf("[mock] Order %s accepted", req.PlatformOrderID),
		ConfirmedAt: time.Now(),
	}, nil
}

func (m *MockDeliveryClient) UpdateOrderStatus(req OrderStatusUpdateRequest) (*OrderStatusUpdateResponse, error) {
	return &OrderStatusUpdateResponse{
		Success: true,
		Message: fmt.Sprintf("[mock] Order %s status updated to %s", req.PlatformOrderID, req.Status),
	}, nil
}

// ─── Foodpanda Client (scaffold) ──────────────────────────────────────────────

// FoodpandaClient integrates with the Foodpanda Restaurant API.
//
// Reference: https://developers.foodpanda.com (partner portal)
// Authentication: API key in X-API-KEY header
// Webhook flow: Foodpanda POSTs new orders to your endpoint → you call ConfirmOrder
type FoodpandaClient struct {
	cfg     Config
	baseURL string
}

func (c *FoodpandaClient) Name() string { return PlatformFoodpanda }

// ConfirmOrder tells Foodpanda the restaurant has accepted the order.
//
// TODO: implement when Foodpanda API key is available.
//
// API: PATCH {baseURL}/api/v1/orders/{platformOrderId}/confirm
//
//	Headers: X-API-KEY: {FoodpandaKey}, Content-Type: application/json
//	Body: { "estimated_prep_time_minutes": req.EstimatedMinutes }
//
// Response: 200 OK = accepted; 4xx = error with message body.
func (c *FoodpandaClient) ConfirmOrder(req OrderConfirmRequest) (*OrderConfirmResponse, error) {
	return nil, fmt.Errorf("Foodpanda not configured: set delivery.mock_mode=true or provide credentials")
}

// UpdateOrderStatus updates Foodpanda on the order's kitchen/pickup status.
//
// TODO: implement when Foodpanda API key is available.
//
// API: PATCH {baseURL}/api/v1/orders/{platformOrderId}/status
//
//	Body: { "status": req.Status }  // "accepted", "ready", "picked_up", etc.
func (c *FoodpandaClient) UpdateOrderStatus(req OrderStatusUpdateRequest) (*OrderStatusUpdateResponse, error) {
	return nil, fmt.Errorf("Foodpanda not configured: set delivery.mock_mode=true or provide credentials")
}

// ─── Uber Eats Client (scaffold) ──────────────────────────────────────────────

// UberEatsClient integrates with the Uber Eats Orders API.
//
// Reference: https://developer.uber.com/docs/eats/introduction
// Authentication: OAuth2 client_credentials flow → Bearer token in all requests
// Webhook flow: Uber Eats POSTs new orders to your endpoint → you call ConfirmOrder
type UberEatsClient struct {
	cfg        Config
	baseURL    string
	accessToken string
	tokenExpiry time.Time
}

func (c *UberEatsClient) Name() string { return PlatformUberEats }

// ensureToken fetches or refreshes the OAuth2 Bearer token.
//
// TODO: implement OAuth2 client_credentials flow:
//
//	POST https://login.uber.com/oauth/v2/token
//	  grant_type=client_credentials
//	  client_id={UberEatsID}
//	  client_secret={UberEatsSecret}
//	  scope=eats.order
//
// Cache the token and refresh when tokenExpiry is near.
func (c *UberEatsClient) ensureToken() error {
	if time.Now().Before(c.tokenExpiry) {
		return nil // token still valid
	}
	// TODO: POST to OAuth2 token endpoint, parse access_token + expires_in
	return fmt.Errorf("Uber Eats OAuth2 not implemented: provide UberEatsID and UberEatsSecret")
}

// ConfirmOrder accepts the order and sends estimated prep time to Uber Eats.
//
// TODO: implement when Uber Eats credentials are available.
//
// API: POST {baseURL}/v1/eats/orders/{platformOrderId}/accept_pos_order
//
//	Headers: Authorization: Bearer {accessToken}, Content-Type: application/json
//	Body: { "reason": { "explanation": "Accepted", "ready_for_pickup_in": req.EstimatedMinutes } }
func (c *UberEatsClient) ConfirmOrder(req OrderConfirmRequest) (*OrderConfirmResponse, error) {
	if err := c.ensureToken(); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("Uber Eats not configured: set delivery.mock_mode=true or provide credentials")
}

// UpdateOrderStatus updates Uber Eats on order kitchen/ready status.
//
// TODO: implement when Uber Eats credentials are available.
//
// API: POST {baseURL}/v1/eats/orders/{platformOrderId}/cancel  (for cancelled)
//       (Uber Eats uses accept/cancel rather than generic status updates)
func (c *UberEatsClient) UpdateOrderStatus(req OrderStatusUpdateRequest) (*OrderStatusUpdateResponse, error) {
	if err := c.ensureToken(); err != nil {
		return nil, err
	}
	return nil, fmt.Errorf("Uber Eats not configured: set delivery.mock_mode=true or provide credentials")
}

// ─── Factory ──────────────────────────────────────────────────────────────────

// NewFoodpandaClient returns a mock or real Foodpanda client based on config.
func NewFoodpandaClient(cfg Config) DeliveryPlatform {
	if cfg.MockMode {
		return &MockDeliveryClient{platform: PlatformFoodpanda}
	}
	baseURL := cfg.FoodpandaURL
	if baseURL == "" {
		baseURL = "https://partner-api.foodpanda.com"
	}
	return &FoodpandaClient{cfg: cfg, baseURL: baseURL}
}

// NewUberEatsClient returns a mock or real Uber Eats client based on config.
func NewUberEatsClient(cfg Config) DeliveryPlatform {
	if cfg.MockMode {
		return &MockDeliveryClient{platform: PlatformUberEats}
	}
	baseURL := cfg.UberEatsURL
	if baseURL == "" {
		baseURL = "https://api.uber.com"
	}
	return &UberEatsClient{cfg: cfg, baseURL: baseURL}
}
