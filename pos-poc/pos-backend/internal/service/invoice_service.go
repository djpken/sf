package service

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/integration/einvoice"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// InvoiceService handles e-invoice business logic.
type InvoiceService struct {
	orderRepo *postgres.OrderRepository
	provider  einvoice.InvoiceProvider
}

// NewInvoiceService creates a new InvoiceService.
func NewInvoiceService(orderRepo *postgres.OrderRepository, provider einvoice.InvoiceProvider) *InvoiceService {
	return &InvoiceService{
		orderRepo: orderRepo,
		provider:  provider,
	}
}

// IssueInvoiceRequest holds parameters for issuing an invoice.
type IssueInvoiceRequest struct {
	BuyerTaxID  string `json:"buyer_tax_id,omitempty"`  // B2B only
	CarrierType string `json:"carrier_type,omitempty"`  // "" | "3J0002" | "CQ0001"
	CarrierNo   string `json:"carrier_no,omitempty"`    // mobile number etc.
}

// VoidInvoiceRequest holds parameters for voiding an invoice.
type VoidInvoiceRequest struct {
	Reason string `json:"reason" binding:"required"`
}

// IssueInvoice creates and issues an e-invoice for a completed order.
func (s *InvoiceService) IssueInvoice(orderID uuid.UUID, req IssueInvoiceRequest) (*domain.Invoice, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil || order == nil {
		return nil, errors.New("order not found")
	}

	// Only issue invoices for paid orders
	if order.PaymentStatus != domain.PaymentStatusPaid {
		return nil, errors.New("invoice can only be issued for fully paid orders")
	}

	// Prevent duplicate invoices
	if order.Invoice != nil {
		return nil, errors.New("invoice already issued for this order")
	}

	// Build line items from order items
	items := make([]einvoice.IssueItem, 0, len(order.Items))
	for _, oi := range order.Items {
		name := "商品"
		if oi.Item != nil {
			name = oi.Item.Name
		}
		items = append(items, einvoice.IssueItem{
			Name:      name,
			Quantity:  oi.Quantity,
			UnitPrice: oi.UnitPrice,
			Amount:    oi.UnitPrice * float64(oi.Quantity),
		})
	}

	// Taiwan tax: 5% (taxed total = amount * 1.05, tax = amount * 0.05)
	taxRate := 0.05
	amount := order.Total / (1 + taxRate) // pre-tax amount
	tax := order.Total - amount           // tax amount

	issueReq := einvoice.IssueRequest{
		OrderID:     orderID.String(),
		OrderNo:     order.OrderNo,
		Amount:      amount,
		Tax:         tax,
		BuyerTaxID:  req.BuyerTaxID,
		CarrierType: req.CarrierType,
		CarrierNo:   req.CarrierNo,
		Items:       items,
	}

	resp, err := s.provider.Issue(issueReq)
	if err != nil {
		return nil, fmt.Errorf("invoice provider error: %w", err)
	}

	// Persist invoice record
	now := resp.IssuedAt
	invoice := &domain.Invoice{
		OrderID:     orderID,
		InvoiceNo:   resp.InvoiceNo,
		RandomCode:  resp.RandomCode,
		BuyerTaxID:  req.BuyerTaxID,
		Amount:      amount,
		Tax:         tax,
		Status:      domain.InvoiceStatusIssued,
		CarrierType: req.CarrierType,
		CarrierNo:   req.CarrierNo,
		IssuedAt:    &now,
		RawResponse: resp.RawResponse,
	}

	if err := s.orderRepo.CreateInvoice(invoice); err != nil {
		return nil, fmt.Errorf("save invoice: %w", err)
	}

	return invoice, nil
}

// GetInvoice retrieves the invoice for an order.
func (s *InvoiceService) GetInvoice(orderID uuid.UUID) (*domain.Invoice, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil || order == nil {
		return nil, errors.New("order not found")
	}
	if order.Invoice == nil {
		return nil, errors.New("no invoice found for this order")
	}
	return order.Invoice, nil
}

// VoidInvoice voids (cancels) an issued invoice.
func (s *InvoiceService) VoidInvoice(orderID uuid.UUID, req VoidInvoiceRequest) (*domain.Invoice, error) {
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil || order == nil {
		return nil, errors.New("order not found")
	}
	if order.Invoice == nil {
		return nil, errors.New("no invoice found for this order")
	}
	if order.Invoice.Status == domain.InvoiceStatusVoided {
		return nil, errors.New("invoice is already voided")
	}

	voidReq := einvoice.VoidRequest{
		InvoiceNo:  order.Invoice.InvoiceNo,
		RandomCode: order.Invoice.RandomCode,
		Reason:     req.Reason,
	}

	resp, err := s.provider.Void(voidReq)
	if err != nil {
		return nil, fmt.Errorf("void provider error: %w", err)
	}
	if !resp.Success {
		return nil, errors.New("provider rejected void request")
	}

	// Update invoice status
	order.Invoice.Status = domain.InvoiceStatusVoided
	if err := s.orderRepo.UpdateInvoice(order.Invoice); err != nil {
		return nil, fmt.Errorf("update invoice: %w", err)
	}

	return order.Invoice, nil
}

// GetInvoiceByNo retrieves an invoice by its invoice number.
func (s *InvoiceService) GetInvoiceByNo(invoiceNo string) (*domain.Invoice, error) {
	return s.orderRepo.FindInvoiceByNo(invoiceNo)
}

// GenerateInvoiceTime formats the current time in Taiwan format (for display).
func GenerateInvoiceTime() string {
	// Taiwan calendar year = Western year - 1911
	now := time.Now()
	twYear := now.Year() - 1911
	return fmt.Sprintf("%d/%02d/%02d", twYear, now.Month(), now.Day())
}
