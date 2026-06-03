package service

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/integration"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// OrderService handles order-related business logic
type OrderService struct {
	orderRepo    *postgres.OrderRepository
	menuRepo     *postgres.MenuRepository
	linePayGW    integration.PaymentGateway
	creditCardGW integration.PaymentGateway
}

// NewOrderService creates a new order service
func NewOrderService(orderRepo *postgres.OrderRepository, menuRepo *postgres.MenuRepository, linePayGW integration.PaymentGateway, creditCardGW integration.PaymentGateway) *OrderService {
	return &OrderService{
		orderRepo:    orderRepo,
		menuRepo:     menuRepo,
		linePayGW:    linePayGW,
		creditCardGW: creditCardGW,
	}
}

// === DTOs ===

// OrderItemRequest represents an item in an order request
type OrderItemRequest struct {
	ItemID   uuid.UUID      `json:"item_id" binding:"required"`
	Quantity int            `json:"quantity" binding:"required,gt=0"`
	Options  map[string]any `json:"options,omitempty"`
	Notes    string         `json:"notes,omitempty"`
}

// CreateOrderRequest represents a request to create an order
type CreateOrderRequest struct {
	OrderType        domain.OrderType   `json:"order_type" binding:"required,oneof=dine_in takeout delivery"`
	TableID          *uuid.UUID         `json:"table_id,omitempty"`
	CustomerName     string             `json:"customer_name,omitempty"`
	CustomerPhone    string             `json:"customer_phone,omitempty"`
	DeliveryAddress  string             `json:"delivery_address,omitempty"`
	DeliveryPlatform string             `json:"delivery_platform,omitempty"`
	Items            []OrderItemRequest `json:"items" binding:"required,min=1"`
	Notes            string             `json:"notes,omitempty"`
}

// UpdateOrderRequest represents a request to update an order
type UpdateOrderRequest struct {
	Status           *domain.OrderStatus `json:"status,omitempty"`
	PaymentStatus    *domain.PaymentStatus `json:"payment_status,omitempty"`
	CustomerName     *string             `json:"customer_name,omitempty"`
	CustomerPhone    *string             `json:"customer_phone,omitempty"`
	DeliveryAddress  *string             `json:"delivery_address,omitempty"`
	Notes            *string             `json:"notes,omitempty"`
}

// AddOrderItemRequest represents a request to add an item to an existing order
type AddOrderItemRequest struct {
	ItemID   uuid.UUID      `json:"item_id" binding:"required"`
	Quantity int            `json:"quantity" binding:"required,gt=0"`
	Options  map[string]any `json:"options,omitempty"`
	Notes    string         `json:"notes,omitempty"`
}

// AddPaymentRequest represents a request to add a payment
type AddPaymentRequest struct {
	Method      domain.PaymentMethod `json:"method" binding:"required,oneof=cash credit_card line_pay other"`
	Amount      float64              `json:"amount" binding:"required,gt=0"`
	Received    *float64             `json:"received,omitempty"`
	ReferenceNo string               `json:"reference_no,omitempty"`
}

// === Order Methods ===

// ListOrders lists orders with filters
func (s *OrderService) ListOrders(storeID uuid.UUID, status *domain.OrderStatus, paymentStatus *domain.PaymentStatus, startDate, endDate *time.Time, limit, offset int) ([]domain.Order, int64, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}

	return s.orderRepo.List(storeID, status, paymentStatus, startDate, endDate, limit, offset)
}

// GetOrder gets an order by ID
func (s *OrderService) GetOrder(id uuid.UUID) (*domain.Order, error) {
	order, err := s.orderRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, errors.New("order not found")
	}
	return order, nil
}

// CreateOrder creates a new order
func (s *OrderService) CreateOrder(storeID, employeeID uuid.UUID, req CreateOrderRequest) (*domain.Order, error) {
	// Validate table for dine-in orders
	if req.OrderType == domain.OrderTypeDineIn && req.TableID == nil {
		return nil, errors.New("table_id is required for dine-in orders")
	}

	// Validate delivery info for delivery orders
	if req.OrderType == domain.OrderTypeDelivery {
		if req.CustomerName == "" || req.CustomerPhone == "" || req.DeliveryAddress == "" {
			return nil, errors.New("customer info and delivery address are required for delivery orders")
		}
	}

	// Generate order number
	orderNo, err := s.orderRepo.GenerateOrderNo(storeID)
	if err != nil {
		return nil, err
	}

	// Calculate totals
	var subtotal float64
	var orderItems []domain.OrderItem

	for _, itemReq := range req.Items {
		// Get menu item
		menuItem, err := s.menuRepo.FindItemByID(itemReq.ItemID)
		if err != nil {
			return nil, err
		}
		if menuItem == nil {
			return nil, errors.New("menu item not found: " + itemReq.ItemID.String())
		}
		if !menuItem.IsActive {
			return nil, errors.New("menu item is not available: " + menuItem.Name)
		}

		// TODO: Check store-specific price if available
		unitPrice := menuItem.Price
		itemSubtotal := unitPrice * float64(itemReq.Quantity)
		subtotal += itemSubtotal

		orderItems = append(orderItems, domain.OrderItem{
			ItemID:    &itemReq.ItemID,
			ItemName:  menuItem.Name,
			UnitPrice: unitPrice,
			Quantity:  itemReq.Quantity,
			Subtotal:  itemSubtotal,
			Options:   itemReq.Options,
			Notes:     itemReq.Notes,
			Status:    domain.OrderItemStatusPending,
		})
	}

	// Calculate tax (5% for example)
	tax := subtotal * 0.05
	total := subtotal + tax

	// Create order
	order := &domain.Order{
		StoreID:          storeID,
		OrderNo:          orderNo,
		OrderType:        req.OrderType,
		TableID:          req.TableID,
		CustomerName:     req.CustomerName,
		CustomerPhone:    req.CustomerPhone,
		DeliveryAddress:  req.DeliveryAddress,
		DeliveryPlatform: req.DeliveryPlatform,
		Subtotal:         subtotal,
		Discount:         0,
		Tax:              tax,
		ServiceCharge:    0,
		Total:            total,
		Status:           domain.OrderStatusPending,
		PaymentStatus:    domain.PaymentStatusUnpaid,
		EmployeeID:       &employeeID,
		Notes:            req.Notes,
		Items:            orderItems,
	}

	if err := s.orderRepo.Create(order); err != nil {
		return nil, err
	}

	// Reload with relations
	return s.orderRepo.FindByID(order.ID)
}

// UpdateOrder updates an order
func (s *OrderService) UpdateOrder(id uuid.UUID, req UpdateOrderRequest) (*domain.Order, error) {
	order, err := s.orderRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, errors.New("order not found")
	}

	// Don't allow updates to completed or cancelled orders
	if order.Status == domain.OrderStatusCompleted || order.Status == domain.OrderStatusCancelled {
		return nil, errors.New("cannot update completed or cancelled orders")
	}

	// Update fields if provided
	if req.Status != nil {
		order.Status = *req.Status
	}
	if req.PaymentStatus != nil {
		order.PaymentStatus = *req.PaymentStatus
	}
	if req.CustomerName != nil {
		order.CustomerName = *req.CustomerName
	}
	if req.CustomerPhone != nil {
		order.CustomerPhone = *req.CustomerPhone
	}
	if req.DeliveryAddress != nil {
		order.DeliveryAddress = *req.DeliveryAddress
	}
	if req.Notes != nil {
		order.Notes = *req.Notes
	}

	if err := s.orderRepo.Update(order); err != nil {
		return nil, err
	}

	return s.orderRepo.FindByID(id)
}

// UpdateOrderStatus updates order status
func (s *OrderService) UpdateOrderStatus(id uuid.UUID, status domain.OrderStatus) error {
	order, err := s.orderRepo.FindByID(id)
	if err != nil {
		return err
	}
	if order == nil {
		return errors.New("order not found")
	}

	return s.orderRepo.UpdateStatus(id, status)
}

// CancelOrder cancels an order
func (s *OrderService) CancelOrder(id uuid.UUID) error {
	order, err := s.orderRepo.FindByID(id)
	if err != nil {
		return err
	}
	if order == nil {
		return errors.New("order not found")
	}

	if order.Status == domain.OrderStatusCompleted {
		return errors.New("cannot cancel completed orders")
	}

	return s.orderRepo.UpdateStatus(id, domain.OrderStatusCancelled)
}

// AddOrderItem adds an item to an existing order
func (s *OrderService) AddOrderItem(orderID uuid.UUID, req AddOrderItemRequest) (*domain.Order, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, errors.New("order not found")
	}

	if order.Status != domain.OrderStatusPending && order.Status != domain.OrderStatusPreparing {
		return nil, errors.New("cannot add items to this order")
	}

	// Get menu item
	menuItem, err := s.menuRepo.FindItemByID(req.ItemID)
	if err != nil {
		return nil, err
	}
	if menuItem == nil {
		return nil, errors.New("menu item not found")
	}

	unitPrice := menuItem.Price
	itemSubtotal := unitPrice * float64(req.Quantity)

	orderItem := &domain.OrderItem{
		OrderID:   orderID,
		ItemID:    &req.ItemID,
		ItemName:  menuItem.Name,
		UnitPrice: unitPrice,
		Quantity:  req.Quantity,
		Subtotal:  itemSubtotal,
		Options:   req.Options,
		Notes:     req.Notes,
		Status:    domain.OrderItemStatusPending,
	}

	if err := s.orderRepo.AddItem(orderItem); err != nil {
		return nil, err
	}

	// Recalculate order totals
	order.Subtotal += itemSubtotal
	order.Tax = order.Subtotal * 0.05
	order.Total = order.Subtotal + order.Tax - order.Discount + order.ServiceCharge

	if err := s.orderRepo.Update(order); err != nil {
		return nil, err
	}

	return s.orderRepo.FindByID(orderID)
}

// === Payment Methods ===

// AddPayment adds a payment to an order
func (s *OrderService) AddPayment(orderID uuid.UUID, req AddPaymentRequest) (*domain.Order, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil {
		return nil, err
	}
	if order == nil {
		return nil, errors.New("order not found")
	}

	if order.PaymentStatus == domain.PaymentStatusPaid {
		return nil, errors.New("order is already paid")
	}

	// Calculate change for cash payments
	var change *float64
	if req.Method == domain.PaymentMethodCash && req.Received != nil {
		c := *req.Received - req.Amount
		if c < 0 {
			return nil, errors.New("received amount is less than payment amount")
		}
		change = &c
	}

	payment := &domain.Payment{
		OrderID:     orderID,
		Method:      req.Method,
		Amount:      req.Amount,
		Received:    req.Received,
		Change:      change,
		ReferenceNo: req.ReferenceNo,
		Status:      domain.PaymentStatusEnumCompleted,
	}

	if err := s.orderRepo.AddPayment(payment); err != nil {
		return nil, err
	}

	// Update order payment status
	payments, _ := s.orderRepo.GetPaymentsByOrder(orderID)
	totalPaid := 0.0
	for _, p := range payments {
		if p.Status == domain.PaymentStatusEnumCompleted {
			totalPaid += p.Amount
		}
	}

	if totalPaid >= order.Total {
		order.PaymentStatus = domain.PaymentStatusPaid
		order.Status = domain.OrderStatusCompleted
	} else if totalPaid > 0 {
		order.PaymentStatus = domain.PaymentStatusPartial
	}

	if err := s.orderRepo.Update(order); err != nil {
		return nil, err
	}

	return s.orderRepo.FindByID(orderID)
}

// === Gateway Payment Methods ===

// InitiateGatewayPaymentRequest holds parameters for initiating a gateway payment.
type InitiateGatewayPaymentRequest struct {
	Method domain.PaymentMethod `json:"method" binding:"required,oneof=line_pay credit_card"`
	Amount float64              `json:"amount" binding:"required,gt=0"`
}

// GatewayPaymentResponse holds the result of a gateway payment initiation.
type GatewayPaymentResponse struct {
	TransactionID string `json:"transaction_id"`
	PaymentURL    string `json:"payment_url,omitempty"`
	Status        string `json:"status"` // "pending" (real) or "completed" (mock)
}

// ConfirmGatewayPaymentRequest holds parameters for confirming a gateway payment.
type ConfirmGatewayPaymentRequest struct {
	TransactionID string  `json:"transaction_id" binding:"required"`
	Amount        float64 `json:"amount" binding:"required,gt=0"`
}

// InitiateGatewayPayment starts a payment via Line Pay or credit card gateway.
// In mock mode, the payment is also immediately recorded as completed.
func (s *OrderService) InitiateGatewayPayment(orderID uuid.UUID, req InitiateGatewayPaymentRequest) (*GatewayPaymentResponse, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil || order == nil {
		return nil, errors.New("order not found")
	}
	if order.PaymentStatus == domain.PaymentStatusPaid {
		return nil, errors.New("order is already paid")
	}

	// Select the appropriate gateway
	var gw integration.PaymentGateway
	switch req.Method {
	case domain.PaymentMethodLinePay:
		gw = s.linePayGW
	case domain.PaymentMethodCreditCard:
		gw = s.creditCardGW
	default:
		return nil, fmt.Errorf("unsupported gateway method: %s", req.Method)
	}

	initiateReq := integration.InitiatePaymentRequest{
		OrderID:     orderID.String(),
		OrderNo:     order.OrderNo,
		Amount:      req.Amount,
		Currency:    "TWD",
		Description: fmt.Sprintf("Order %s", order.OrderNo),
	}

	resp, err := gw.Initiate(initiateReq)
	if err != nil {
		return nil, fmt.Errorf("gateway initiate failed: %w", err)
	}

	// In mock mode (status=completed), immediately record the payment
	if resp.Status == "completed" {
		addReq := AddPaymentRequest{
			Method:      req.Method,
			Amount:      req.Amount,
			ReferenceNo: resp.TransactionID,
		}
		if _, err := s.AddPayment(orderID, addReq); err != nil {
			return nil, fmt.Errorf("record mock payment: %w", err)
		}
	}

	return &GatewayPaymentResponse{
		TransactionID: resp.TransactionID,
		PaymentURL:    resp.PaymentURL,
		Status:        resp.Status,
	}, nil
}

// ConfirmGatewayPayment verifies and finalizes a gateway payment.
// Used in real mode after the user completes payment on the gateway's page.
// In mock mode, the payment was already recorded in InitiateGatewayPayment.
func (s *OrderService) ConfirmGatewayPayment(orderID uuid.UUID, req ConfirmGatewayPaymentRequest) (*domain.Order, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil || order == nil {
		return nil, errors.New("order not found")
	}

	// Check if already paid (mock mode records it in Initiate)
	if order.PaymentStatus == domain.PaymentStatusPaid {
		return order, nil
	}

	// In real mode, confirm with the gateway and record payment
	// Determine which gateway to use from existing payments (by transactionID in ReferenceNo)
	// For simplicity, we try both gateways
	for _, gw := range []integration.PaymentGateway{s.linePayGW, s.creditCardGW} {
		confirmReq := integration.ConfirmPaymentRequest{
			TransactionID: req.TransactionID,
			OrderID:       orderID.String(),
			Amount:        req.Amount,
		}
		confirmResp, err := gw.Confirm(confirmReq)
		if err != nil {
			continue
		}
		if confirmResp.Success {
			method := domain.PaymentMethodLinePay
			if gw.Name() == "credit_card" {
				method = domain.PaymentMethodCreditCard
			}
			addReq := AddPaymentRequest{
				Method:      method,
				Amount:      confirmResp.Amount,
				ReferenceNo: confirmResp.ReferenceNo,
			}
			return s.AddPayment(orderID, addReq)
		}
	}

	return nil, errors.New("payment confirmation failed")
}

// === Statistics ===

// GetDailySales gets daily sales for a store
func (s *OrderService) GetDailySales(storeID uuid.UUID, date time.Time) (float64, error) {
	return s.orderRepo.GetDailySales(storeID, date)
}
