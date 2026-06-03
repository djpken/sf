package linepay

import (
	"fmt"
	"time"

	"github.com/yourusername/pos-backend/internal/integration"
)

// Config holds Line Pay configuration.
type Config struct {
	ChannelID     string
	ChannelSecret string
	IsSandbox     bool
	MockMode      bool
}

// MockLinePayClient is an in-process mock that returns instant success.
// Use this when no real Line Pay credentials are available.
type MockLinePayClient struct{}

func (m *MockLinePayClient) Name() string { return "line_pay" }

func (m *MockLinePayClient) Initiate(req integration.InitiatePaymentRequest) (*integration.InitiatePaymentResponse, error) {
	txID := fmt.Sprintf("mock-lp-%d", time.Now().UnixMilli())
	return &integration.InitiatePaymentResponse{
		TransactionID: txID,
		PaymentURL:    "", // no redirect needed in mock mode
		Status:        "completed",
	}, nil
}

func (m *MockLinePayClient) Confirm(req integration.ConfirmPaymentRequest) (*integration.ConfirmPaymentResponse, error) {
	return &integration.ConfirmPaymentResponse{
		Success:       true,
		TransactionID: req.TransactionID,
		Amount:        req.Amount,
		ReferenceNo:   req.TransactionID,
	}, nil
}

// LinePayClient is the real Line Pay v3 API client.
// Requires ChannelID and ChannelSecret from the Line Pay merchant console.
// Set IsSandbox=true for sandbox environment.
//
// Reference: https://pay.line.me/documents/online_v3_en.html
type LinePayClient struct {
	cfg     Config
	baseURL string
}

// NewClient returns a MockLinePayClient when cfg.MockMode is true,
// otherwise returns a real LinePayClient.
func NewClient(cfg Config) integration.PaymentGateway {
	if cfg.MockMode {
		return &MockLinePayClient{}
	}
	baseURL := "https://api-pay.line.me"
	if cfg.IsSandbox {
		baseURL = "https://sandbox-api-pay.line.me"
	}
	return &LinePayClient{cfg: cfg, baseURL: baseURL}
}

func (c *LinePayClient) Name() string { return "line_pay" }

// Initiate calls Line Pay v3 /v3/payments/request API.
// TODO: implement HMAC-SHA256 signature and HTTP call when real keys are available.
func (c *LinePayClient) Initiate(req integration.InitiatePaymentRequest) (*integration.InitiatePaymentResponse, error) {
	// IMPLEMENTATION NOTES:
	// 1. Build request body:
	//    POST /v3/payments/request
	//    Headers: X-LINE-ChannelId, X-LINE-Authorization-Nonce, X-LINE-Authorization (HMAC-SHA256)
	//    Body: { amount, currency, orderId, packages: [{id, amount, products}], redirectUrls: {confirmUrl} }
	//
	// 2. Sign: HMAC-SHA256(ChannelSecret, ChannelSecret + URI + body + nonce)
	//
	// 3. Parse response: returnCode "0000" = success
	//    Extract: info.paymentUrl.web (redirect user here)
	//             info.transactionId
	//
	// 4. Return InitiatePaymentResponse{TransactionID, PaymentURL, Status: "pending"}
	return nil, fmt.Errorf("real Line Pay not configured: set payment.mock_mode=true or provide credentials")
}

// Confirm calls Line Pay v3 /v3/payments/{transactionId}/confirm API.
// TODO: implement when real keys are available.
func (c *LinePayClient) Confirm(req integration.ConfirmPaymentRequest) (*integration.ConfirmPaymentResponse, error) {
	// IMPLEMENTATION NOTES:
	// 1. POST /v3/payments/{transactionId}/confirm
	//    Headers: same HMAC-SHA256 signature as Initiate
	//    Body: { amount, currency }
	//
	// 2. Parse response: returnCode "0000" = success
	//
	// 3. Return ConfirmPaymentResponse{Success: true, ...}
	return nil, fmt.Errorf("real Line Pay not configured: set payment.mock_mode=true or provide credentials")
}
