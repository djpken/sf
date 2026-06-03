package service

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/integration/delivery"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// DeliveryService handles incoming delivery platform orders and status updates.
type DeliveryService struct {
	orderRepo    *postgres.OrderRepository
	menuRepo     *postgres.MenuRepository
	foodpanda    delivery.DeliveryPlatform
	uberEats     delivery.DeliveryPlatform
	defaultStore uuid.UUID // store ID to assign delivery orders to
}

// NewDeliveryService creates a new DeliveryService.
func NewDeliveryService(
	orderRepo *postgres.OrderRepository,
	menuRepo *postgres.MenuRepository,
	foodpanda delivery.DeliveryPlatform,
	uberEats delivery.DeliveryPlatform,
	defaultStoreID uuid.UUID,
) *DeliveryService {
	return &DeliveryService{
		orderRepo:    orderRepo,
		menuRepo:     menuRepo,
		foodpanda:    foodpanda,
		uberEats:     uberEats,
		defaultStore: defaultStoreID,
	}
}

// === DTOs ===

// IncomingDeliveryOrderRequest is the webhook payload from a delivery platform.
// Both Foodpanda and Uber Eats payloads are normalised into this struct
// before being processed.
type IncomingDeliveryOrderRequest struct {
	Platform        string                        `json:"platform" binding:"required,oneof=foodpanda uber_eats mock"`
	PlatformOrderID string                        `json:"platform_order_id" binding:"required"`
	CustomerName    string                        `json:"customer_name"`
	CustomerPhone   string                        `json:"customer_phone"`
	DeliveryAddress string                        `json:"delivery_address"`
	Items           []IncomingDeliveryItemRequest `json:"items" binding:"required,min=1"`
	Notes           string                        `json:"notes"`
}

// IncomingDeliveryItemRequest represents a single item from the platform.
type IncomingDeliveryItemRequest struct {
	ExternalItemID string  `json:"external_item_id"`
	Name           string  `json:"name" binding:"required"`
	Quantity       int     `json:"quantity" binding:"required,gt=0"`
	UnitPrice      float64 `json:"unit_price" binding:"required,gt=0"`
}

// DeliveryOrderResponse is returned after processing an incoming delivery order.
type DeliveryOrderResponse struct {
	OrderID         string    `json:"order_id"`
	OrderNo         string    `json:"order_no"`
	PlatformOrderID string    `json:"platform_order_id"`
	Platform        string    `json:"platform"`
	Status          string    `json:"status"`
	Total           float64   `json:"total"`
	EstimatedMinutes int      `json:"estimated_minutes"`
	CreatedAt       time.Time `json:"created_at"`
}

// UpdateDeliveryStatusRequest updates the platform on order progress.
type UpdateDeliveryStatusRequest struct {
	Platform        string `json:"platform" binding:"required,oneof=foodpanda uber_eats mock"`
	PlatformOrderID string `json:"platform_order_id" binding:"required"`
	Status          string `json:"status" binding:"required,oneof=accepted ready picked_up delivered cancelled"`
}

// === Methods ===

// ReceiveOrder processes an incoming order from a delivery platform:
//  1. Creates a local Order record (type=delivery)
//  2. Confirms receipt with the platform (sends estimated prep time)
//  3. Returns the created order details
func (s *DeliveryService) ReceiveOrder(req IncomingDeliveryOrderRequest) (*DeliveryOrderResponse, error) {
	// Build order items from platform payload
	items := make([]domain.OrderItem, 0, len(req.Items))
	var subtotal float64
	for _, it := range req.Items {
		lineTotal := it.UnitPrice * float64(it.Quantity)
		subtotal += lineTotal
		items = append(items, domain.OrderItem{
			ItemName:  it.Name,
			UnitPrice: it.UnitPrice,
			Quantity:  it.Quantity,
			Subtotal:  lineTotal,
			Status:    domain.OrderItemStatusPending,
		})
	}

	tax := subtotal * 0.05 // 5% VAT
	total := subtotal + tax

	orderNo := fmt.Sprintf("DLV-%s-%d",
		uppercasePlatformCode(req.Platform),
		time.Now().UnixMilli()%1000000,
	)

	order := &domain.Order{
		StoreID:          s.defaultStore,
		OrderNo:          orderNo,
		OrderType:        domain.OrderTypeDelivery,
		DeliveryPlatform: req.Platform,
		DeliveryAddress:  req.DeliveryAddress,
		CustomerName:     req.CustomerName,
		CustomerPhone:    req.CustomerPhone,
		Notes:            req.Notes,
		Subtotal:         subtotal,
		Tax:              tax,
		Total:            total,
		Status:           domain.OrderStatusPending,
		PaymentStatus:    domain.PaymentStatusPaid, // delivery platforms pay in advance
		Items:            items,
	}

	if err := s.orderRepo.Create(order); err != nil {
		return nil, fmt.Errorf("failed to create delivery order: %w", err)
	}

	// Confirm receipt with the platform (default 20-minute prep time)
	const estimatedMinutes = 20
	platform := s.platformFor(req.Platform)
	if _, err := platform.ConfirmOrder(delivery.OrderConfirmRequest{
		PlatformOrderID:  req.PlatformOrderID,
		EstimatedMinutes: estimatedMinutes,
	}); err != nil {
		// Non-fatal: order is saved locally, platform confirmation can be retried
		_ = err
	}

	return &DeliveryOrderResponse{
		OrderID:          order.ID.String(),
		OrderNo:          order.OrderNo,
		PlatformOrderID:  req.PlatformOrderID,
		Platform:         req.Platform,
		Status:           string(order.Status),
		Total:            order.Total,
		EstimatedMinutes: estimatedMinutes,
		CreatedAt:        order.CreatedAt,
	}, nil
}

// UpdateStatus pushes an order status update to the delivery platform.
func (s *DeliveryService) UpdateStatus(req UpdateDeliveryStatusRequest) error {
	platform := s.platformFor(req.Platform)
	resp, err := platform.UpdateOrderStatus(delivery.OrderStatusUpdateRequest{
		PlatformOrderID: req.PlatformOrderID,
		Status:          delivery.PlatformOrderStatus(req.Status),
	})
	if err != nil {
		return fmt.Errorf("failed to update delivery platform: %w", err)
	}
	if !resp.Success {
		return fmt.Errorf("platform rejected status update: %s", resp.Message)
	}
	return nil
}

// platformFor returns the right client based on platform name.
func (s *DeliveryService) platformFor(platform string) delivery.DeliveryPlatform {
	switch platform {
	case delivery.PlatformUberEats:
		return s.uberEats
	default: // foodpanda + mock
		return s.foodpanda
	}
}

// uppercasePlatformCode returns a short code for order numbering.
func uppercasePlatformCode(platform string) string {
	switch platform {
	case delivery.PlatformFoodpanda:
		return "FP"
	case delivery.PlatformUberEats:
		return "UE"
	default:
		return "DL"
	}
}
