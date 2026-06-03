package creditcard

import (
	"fmt"
	"time"

	"github.com/yourusername/pos-backend/internal/integration"
)

// Config holds TapPay (credit card) configuration.
type Config struct {
	PartnerKey string
	MerchantID string
	IsSandbox  bool
	MockMode   bool
}

// MockCreditCardClient is an in-process mock that returns instant success.
type MockCreditCardClient struct{}

func (m *MockCreditCardClient) Name() string { return "credit_card" }

func (m *MockCreditCardClient) Initiate(req integration.InitiatePaymentRequest) (*integration.InitiatePaymentResponse, error) {
	txID := fmt.Sprintf("mock-cc-%d", time.Now().UnixMilli())
	return &integration.InitiatePaymentResponse{
		TransactionID: txID,
		PaymentURL:    "",
		Status:        "completed",
	}, nil
}

func (m *MockCreditCardClient) Confirm(req integration.ConfirmPaymentRequest) (*integration.ConfirmPaymentResponse, error) {
	return &integration.ConfirmPaymentResponse{
		Success:       true,
		TransactionID: req.TransactionID,
		Amount:        req.Amount,
		ReferenceNo:   req.TransactionID,
	}, nil
}

// TapPayClient is the real TapPay credit card payment client.
// Requires PartnerKey and MerchantID from TapPay merchant console.
// Set IsSandbox=true for sandbox environment.
//
// Reference: https://docs.tappaysdk.com/tutorial/zh/back-end/go.html
type TapPayClient struct {
	cfg     Config
	baseURL string
}

// NewClient returns a MockCreditCardClient when cfg.MockMode is true,
// otherwise returns a real TapPayClient.
func NewClient(cfg Config) integration.PaymentGateway {
	if cfg.MockMode {
		return &MockCreditCardClient{}
	}
	baseURL := "https://prod.tappaysdk.com"
	if cfg.IsSandbox {
		baseURL = "https://sandbox.tappaysdk.com"
	}
	return &TapPayClient{cfg: cfg, baseURL: baseURL}
}

func (c *TapPayClient) Name() string { return "credit_card" }

// Initiate calls TapPay pay-by-prime API with a card prime token.
// TODO: implement when real keys are available.
func (c *TapPayClient) Initiate(req integration.InitiatePaymentRequest) (*integration.InitiatePaymentResponse, error) {
	// IMPLEMENTATION NOTES:
	// 1. The frontend must first call TapPay.getPrime() to get a card prime token.
	//    The prime token should be included in the request (extend InitiatePaymentRequest.Prime).
	//
	// 2. POST /tpc/payment/pay-by-prime
	//    Headers: Content-Type: application/json, x-api-key: PartnerKey
	//    Body: {
	//      prime: <token from frontend>,
	//      partner_key: PartnerKey,
	//      merchant_id: MerchantID,
	//      amount: req.Amount,
	//      currency: "TWD",
	//      details: req.Description,
	//      cardholder: { name, email, phone_number }
	//    }
	//
	// 3. Parse response: status == 0 = success
	//    Extract: rec_trade_id (= ReferenceNo)
	//
	// 4. Return InitiatePaymentResponse{TransactionID: rec_trade_id, Status: "completed"}
	return nil, fmt.Errorf("real TapPay not configured: set payment.mock_mode=true or provide credentials")
}

// Confirm is a no-op for TapPay (payment is completed in Initiate).
func (c *TapPayClient) Confirm(req integration.ConfirmPaymentRequest) (*integration.ConfirmPaymentResponse, error) {
	// TapPay pay-by-prime completes synchronously in Initiate.
	// This method exists only for interface compliance.
	return &integration.ConfirmPaymentResponse{
		Success:       true,
		TransactionID: req.TransactionID,
		Amount:        req.Amount,
		ReferenceNo:   req.TransactionID,
	}, nil
}
