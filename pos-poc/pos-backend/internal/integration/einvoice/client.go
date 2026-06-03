package einvoice

import (
	"fmt"
	"math/rand"
	"time"
)

// Config holds e-invoice provider configuration.
type Config struct {
	Provider     string // "ecpay", "greenpay", or "mock"
	MerchantID   string // ECPay merchant ID
	HashKey      string // ECPay HashKey
	HashIV       string // ECPay HashIV
	IsSandbox    bool
	MockMode     bool
	SellerTaxID  string // Seller's tax ID (uniform number)
	SellerName   string // Seller's company name
}

// IssueRequest holds the data needed to issue an e-invoice.
type IssueRequest struct {
	OrderID     string
	OrderNo     string
	Amount      float64 // pre-tax amount
	Tax         float64 // tax amount
	BuyerTaxID  string  // buyer's tax ID (B2B); empty for B2C
	CarrierType string  // "" = paper, "3J0002" = mobile carrier, "CQ0001" = cloud invoice
	CarrierNo   string  // carrier number (e.g. phone number for mobile carrier)
	Items       []IssueItem
}

// IssueItem represents a line item on the invoice.
type IssueItem struct {
	Name     string
	Quantity int
	UnitPrice float64
	Amount   float64
}

// IssueResponse holds the result of issuing an invoice.
type IssueResponse struct {
	InvoiceNo   string
	RandomCode  string
	IssuedAt    time.Time
	RawResponse map[string]any
}

// VoidRequest holds data needed to void an invoice.
type VoidRequest struct {
	InvoiceNo  string
	RandomCode string
	Reason     string
}

// VoidResponse holds the result of voiding an invoice.
type VoidResponse struct {
	Success     bool
	RawResponse map[string]any
}

// InvoiceProvider defines the interface for e-invoice provider integrations.
type InvoiceProvider interface {
	Issue(req IssueRequest) (*IssueResponse, error)
	Void(req VoidRequest) (*VoidResponse, error)
	Name() string
}

// ─── Mock Provider ────────────────────────────────────────────────────────────

// MockInvoiceProvider returns instant success without external API calls.
// Generates realistic-looking Taiwan invoice numbers and random codes.
type MockInvoiceProvider struct{}

func (m *MockInvoiceProvider) Name() string { return "mock" }

func (m *MockInvoiceProvider) Issue(req IssueRequest) (*IssueResponse, error) {
	// Taiwan invoice number format: 2-letter prefix + 8 digits
	// e.g. AB12345678
	prefixes := []string{"AA", "AB", "AC", "BA", "BB", "CA"}
	prefix := prefixes[rand.Intn(len(prefixes))]
	number := rand.Intn(99999999)
	invoiceNo := fmt.Sprintf("%s%08d", prefix, number)

	// 4-digit random code
	randomCode := fmt.Sprintf("%04d", rand.Intn(10000))

	now := time.Now()
	return &IssueResponse{
		InvoiceNo:  invoiceNo,
		RandomCode: randomCode,
		IssuedAt:   now,
		RawResponse: map[string]any{
			"provider":   "mock",
			"invoice_no": invoiceNo,
			"issued_at":  now.Format(time.RFC3339),
		},
	}, nil
}

func (m *MockInvoiceProvider) Void(req VoidRequest) (*VoidResponse, error) {
	return &VoidResponse{
		Success: true,
		RawResponse: map[string]any{
			"provider":   "mock",
			"invoice_no": req.InvoiceNo,
			"voided_at":  time.Now().Format(time.RFC3339),
		},
	}, nil
}

// ─── ECPay Provider (scaffold) ────────────────────────────────────────────────

// ECPayProvider integrates with ECPay e-invoice API (綠界科技電子發票).
//
// Reference: https://developers.ecpay.com.tw/?p=2486
// Sandbox: https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue
// Production: https://einvoice.ecpay.com.tw/B2CInvoice/Issue
type ECPayProvider struct {
	cfg     Config
	baseURL string
}

func (e *ECPayProvider) Name() string { return "ecpay" }

// Issue calls ECPay B2CInvoice/Issue API.
// TODO: implement AES-CBC encryption of parameters and HTTP POST when credentials available.
func (e *ECPayProvider) Issue(req IssueRequest) (*IssueResponse, error) {
	// IMPLEMENTATION NOTES:
	// 1. Build parameter string (URL-encoded, sorted by ASCII):
	//    MerchantID, RelateNumber, CustomerEmail, Print, Donation,
	//    TaxType (1=taxed), SalesAmount, InvoiceDesc, Items (pipe-separated),
	//    TimeStamp, CarrierType, CarrierNum
	//
	// 2. Encrypt parameters:
	//    - AES-CBC-256 encrypt with HashKey (key) and HashIV (iv)
	//    - URL-encode result → Data field
	//
	// 3. POST to {baseURL}/B2CInvoice/Issue:
	//    MerchantID=xxx&RqHeader={"Timestamp":xxx,"Revision":"3.0.0"}&Data=<encrypted>
	//
	// 4. Decrypt response Data field with same AES key/iv
	//    Parse: RtnCode==1 means success
	//    Extract: InvoiceNo, RandomNumber, InvoiceDate
	//
	// 5. Return IssueResponse{InvoiceNo, RandomCode: RandomNumber, ...}
	return nil, fmt.Errorf("ECPay not configured: set invoice.mock_mode=true or provide credentials")
}

// Void calls ECPay B2CInvoice/Invalid (作廢發票) API.
// TODO: implement when credentials are available.
func (e *ECPayProvider) Void(req VoidRequest) (*VoidResponse, error) {
	// IMPLEMENTATION NOTES:
	// 1. Build parameters: MerchantID, InvoiceNo, InvoiceDate, Reason
	// 2. AES-CBC encrypt → POST to {baseURL}/B2CInvoice/Invalid
	// 3. Decrypt response, check RtnCode==1
	return nil, fmt.Errorf("ECPay not configured: set invoice.mock_mode=true or provide credentials")
}

// ─── Factory ──────────────────────────────────────────────────────────────────

// NewProvider returns the appropriate InvoiceProvider based on config.
func NewProvider(cfg Config) InvoiceProvider {
	if cfg.MockMode {
		return &MockInvoiceProvider{}
	}
	baseURL := "https://einvoice.ecpay.com.tw"
	if cfg.IsSandbox {
		baseURL = "https://einvoice-stage.ecpay.com.tw"
	}
	return &ECPayProvider{cfg: cfg, baseURL: baseURL}
}
