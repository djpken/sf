package handler

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// OrderHandler handles order-related endpoints
type OrderHandler struct {
	orderService *service.OrderService
}

// NewOrderHandler creates a new order handler
func NewOrderHandler(orderService *service.OrderService) *OrderHandler {
	return &OrderHandler{
		orderService: orderService,
	}
}

// ListOrders lists orders with filters
// @Summary List orders
// @Tags orders
// @Produce json
// @Param status query string false "Filter by status"
// @Param payment_status query string false "Filter by payment status"
// @Param start_date query string false "Start date (RFC3339)"
// @Param end_date query string false "End date (RFC3339)"
// @Param limit query int false "Limit" default(50)
// @Param offset query int false "Offset" default(0)
// @Success 200 {object} object{data=[]domain.Order,total=int64}
// @Security BearerAuth
// @Router /orders [get]
func (h *OrderHandler) ListOrders(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	// Parse filters
	var status *domain.OrderStatus
	if s := c.Query("status"); s != "" {
		st := domain.OrderStatus(s)
		status = &st
	}

	var paymentStatus *domain.PaymentStatus
	if ps := c.Query("payment_status"); ps != "" {
		pst := domain.PaymentStatus(ps)
		paymentStatus = &pst
	}

	var startDate, endDate *time.Time
	if sd := c.Query("start_date"); sd != "" {
		t, err := time.Parse(time.RFC3339, sd)
		if err != nil {
			utils.BadRequestResponse(c, "Invalid start_date format")
			return
		}
		startDate = &t
	}
	if ed := c.Query("end_date"); ed != "" {
		t, err := time.Parse(time.RFC3339, ed)
		if err != nil {
			utils.BadRequestResponse(c, "Invalid end_date format")
			return
		}
		endDate = &t
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	orders, total, err := h.orderService.ListOrders(storeID.(uuid.UUID), status, paymentStatus, startDate, endDate, limit, offset)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, gin.H{
		"data":  orders,
		"total": total,
		"limit": limit,
		"offset": offset,
	})
}

// GetOrder gets an order by ID
// @Summary Get order by ID
// @Tags orders
// @Produce json
// @Param id path string true "Order ID"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders/{id} [get]
func (h *OrderHandler) GetOrder(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	order, err := h.orderService.GetOrder(id)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, order)
}

// CreateOrder creates a new order
// @Summary Create order
// @Tags orders
// @Accept json
// @Produce json
// @Param request body service.CreateOrderRequest true "Order data"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders [post]
func (h *OrderHandler) CreateOrder(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	userID, _ := c.Get("user_id")

	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	var req service.CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	order, err := h.orderService.CreateOrder(storeID.(uuid.UUID), userID.(uuid.UUID), req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Order created successfully", order)
}

// UpdateOrder updates an order
// @Summary Update order
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.UpdateOrderRequest true "Order data"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders/{id} [put]
func (h *OrderHandler) UpdateOrder(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.UpdateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	order, err := h.orderService.UpdateOrder(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Order updated successfully", order)
}

// UpdateOrderStatus updates order status
// @Summary Update order status
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body object{status=string} true "Status"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /orders/{id}/status [put]
func (h *OrderHandler) UpdateOrderStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req struct {
		Status domain.OrderStatus `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	if err := h.orderService.UpdateOrderStatus(id, req.Status); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Order status updated successfully", nil)
}

// CancelOrder cancels an order
// @Summary Cancel order
// @Tags orders
// @Produce json
// @Param id path string true "Order ID"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /orders/{id}/cancel [post]
func (h *OrderHandler) CancelOrder(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	if err := h.orderService.CancelOrder(id); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Order cancelled successfully", nil)
}

// AddOrderItem adds an item to an existing order
// @Summary Add item to order
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.AddOrderItemRequest true "Item data"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders/{id}/items [post]
func (h *OrderHandler) AddOrderItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.AddOrderItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	order, err := h.orderService.AddOrderItem(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Item added successfully", order)
}

// AddPayment adds a payment to an order
// @Summary Add payment to order
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.AddPaymentRequest true "Payment data"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders/{id}/payments [post]
func (h *OrderHandler) AddPayment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.AddPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	order, err := h.orderService.AddPayment(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Payment added successfully", order)
}

// InitiateGatewayPayment initiates a payment via Line Pay or credit card gateway.
// @Summary Initiate gateway payment
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.InitiateGatewayPaymentRequest true "Gateway payment request"
// @Success 200 {object} service.GatewayPaymentResponse
// @Security BearerAuth
// @Router /orders/{id}/payments/gateway [post]
func (h *OrderHandler) InitiateGatewayPayment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.InitiateGatewayPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	resp, err := h.orderService.InitiateGatewayPayment(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Gateway payment initiated", resp)
}

// ConfirmGatewayPayment confirms a gateway payment after user redirect.
// @Summary Confirm gateway payment
// @Tags orders
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.ConfirmGatewayPaymentRequest true "Confirm request"
// @Success 200 {object} domain.Order
// @Security BearerAuth
// @Router /orders/{id}/payments/gateway/confirm [post]
func (h *OrderHandler) ConfirmGatewayPayment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.ConfirmGatewayPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	order, err := h.orderService.ConfirmGatewayPayment(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Payment confirmed", order)
}

// GetDailySales gets daily sales for a store
// @Summary Get daily sales
// @Tags orders
// @Produce json
// @Param date query string false "Date (YYYY-MM-DD)" default(today)
// @Success 200 {object} object{date=string,total_sales=float64}
// @Security BearerAuth
// @Router /orders/sales/daily [get]
func (h *OrderHandler) GetDailySales(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	dateStr := c.DefaultQuery("date", time.Now().Format("2006-01-02"))
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid date format (use YYYY-MM-DD)")
		return
	}

	total, err := h.orderService.GetDailySales(storeID.(uuid.UUID), date)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, gin.H{
		"date":        dateStr,
		"total_sales": total,
	})
}
