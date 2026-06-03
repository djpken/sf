package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// InvoiceHandler handles e-invoice-related endpoints.
type InvoiceHandler struct {
	invoiceService *service.InvoiceService
}

// NewInvoiceHandler creates a new InvoiceHandler.
func NewInvoiceHandler(invoiceService *service.InvoiceService) *InvoiceHandler {
	return &InvoiceHandler{invoiceService: invoiceService}
}

// IssueInvoice issues an e-invoice for a completed order.
// @Summary Issue e-invoice for order
// @Tags invoices
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.IssueInvoiceRequest false "Invoice options"
// @Success 200 {object} domain.Invoice
// @Security BearerAuth
// @Router /orders/{id}/invoice [post]
func (h *InvoiceHandler) IssueInvoice(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.IssueInvoiceRequest
	// body is optional (all fields optional); ignore bind error
	_ = c.ShouldBindJSON(&req)

	invoice, err := h.invoiceService.IssueInvoice(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Invoice issued successfully", invoice)
}

// GetInvoice retrieves the invoice for an order.
// @Summary Get invoice for order
// @Tags invoices
// @Produce json
// @Param id path string true "Order ID"
// @Success 200 {object} domain.Invoice
// @Security BearerAuth
// @Router /orders/{id}/invoice [get]
func (h *InvoiceHandler) GetInvoice(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	invoice, err := h.invoiceService.GetInvoice(id)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, invoice)
}

// VoidInvoice voids an issued invoice.
// @Summary Void an invoice
// @Tags invoices
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body service.VoidInvoiceRequest true "Void reason"
// @Success 200 {object} domain.Invoice
// @Security BearerAuth
// @Router /orders/{id}/invoice/void [post]
func (h *InvoiceHandler) VoidInvoice(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid order ID")
		return
	}

	var req service.VoidInvoiceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	invoice, err := h.invoiceService.VoidInvoice(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Invoice voided successfully", invoice)
}
