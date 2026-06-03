package integration

// PaymentGateway defines the interface for payment gateway integrations.
// Both mock and real implementations must satisfy this interface.
type PaymentGateway interface {
	// Initiate starts a payment transaction.
	// For Line Pay: returns a payment URL to redirect the user.
	// For credit card (TapPay): processes immediately.
	Initiate(req InitiatePaymentRequest) (*InitiatePaymentResponse, error)

	// Confirm verifies and finalises a payment transaction.
	Confirm(req ConfirmPaymentRequest) (*ConfirmPaymentResponse, error)

	// Name returns the gateway identifier (e.g. "line_pay", "credit_card").
	Name() string
}

// InitiatePaymentRequest carries the data needed to start a payment.
type InitiatePaymentRequest struct {
	OrderID     string
	OrderNo     string
	Amount      float64
	Currency    string // default "TWD"
	Description string
	ReturnURL   string // callback URL after payment
}

// InitiatePaymentResponse is the result of initiating a payment.
type InitiatePaymentResponse struct {
	TransactionID string
	PaymentURL    string // redirect URL (Line Pay); empty for credit card
	// "pending"   – user must complete payment on gateway page
	// "completed" – mock mode: payment finished immediately
	Status string
}

// ConfirmPaymentRequest carries data needed to confirm/verify a transaction.
type ConfirmPaymentRequest struct {
	TransactionID string
	OrderID       string
	Amount        float64
}

// ConfirmPaymentResponse is the result of confirming a payment.
type ConfirmPaymentResponse struct {
	Success       bool
	TransactionID string
	Amount        float64
	ReferenceNo   string // gateway-issued reference number
}
