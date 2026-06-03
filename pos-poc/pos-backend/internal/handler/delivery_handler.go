package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// DeliveryHandler handles incoming orders and status updates from delivery platforms.
type DeliveryHandler struct {
	deliveryService *service.DeliveryService
}

// NewDeliveryHandler creates a new DeliveryHandler.
func NewDeliveryHandler(deliveryService *service.DeliveryService) *DeliveryHandler {
	return &DeliveryHandler{deliveryService: deliveryService}
}

// ReceiveOrder processes an incoming order webhook from a delivery platform.
//
// @Summary Receive a new order from a delivery platform
// @Tags delivery
// @Accept json
// @Produce json
// @Param request body service.IncomingDeliveryOrderRequest true "Incoming delivery order"
// @Success 201 {object} service.DeliveryOrderResponse
// @Security BearerAuth
// @Router /delivery/orders [post]
//
// In production, Foodpanda and Uber Eats POST their webhook payloads to this
// endpoint. The payload is normalised into IncomingDeliveryOrderRequest before
// being processed.
func (h *DeliveryHandler) ReceiveOrder(c *gin.Context) {
	var req service.IncomingDeliveryOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	resp, err := h.deliveryService.ReceiveOrder(req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Delivery order received", resp)
}

// UpdateStatus pushes a status update to the delivery platform.
//
// @Summary Update delivery order status on platform
// @Tags delivery
// @Accept json
// @Produce json
// @Param request body service.UpdateDeliveryStatusRequest true "Status update"
// @Success 200
// @Security BearerAuth
// @Router /delivery/status [post]
//
// Called internally (e.g. from kitchen display system) after the order
// reaches a new stage: accepted → ready → picked_up.
func (h *DeliveryHandler) UpdateStatus(c *gin.Context) {
	var req service.UpdateDeliveryStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	if err := h.deliveryService.UpdateStatus(req); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Status updated successfully", nil)
}
