package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// InvoiceStatus represents the status of an invoice
type InvoiceStatus string

const (
	InvoiceStatusPending InvoiceStatus = "pending"
	InvoiceStatusIssued  InvoiceStatus = "issued"
	InvoiceStatusVoided  InvoiceStatus = "voided"
)

// Invoice represents an electronic invoice
type Invoice struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	OrderID     uuid.UUID      `gorm:"type:uuid;not null" json:"order_id"`
	InvoiceNo   string         `gorm:"type:varchar(20)" json:"invoice_no,omitempty"`
	RandomCode  string         `gorm:"type:varchar(4)" json:"random_code,omitempty"`
	BuyerTaxID  string         `gorm:"type:varchar(10)" json:"buyer_tax_id,omitempty"`
	Amount      float64        `gorm:"type:decimal(10,2)" json:"amount"`
	Tax         float64        `gorm:"type:decimal(10,2)" json:"tax"`
	Status      InvoiceStatus  `gorm:"type:varchar(20)" json:"status"`
	CarrierType string         `gorm:"type:varchar(20)" json:"carrier_type,omitempty"`
	CarrierNo   string         `gorm:"type:varchar(50)" json:"carrier_no,omitempty"`
	IssuedAt    *time.Time     `json:"issued_at,omitempty"`
	RawResponse map[string]any `gorm:"type:jsonb" json:"raw_response,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`

	// Relations
	Order *Order `gorm:"foreignKey:OrderID" json:"order,omitempty"`
}

// TableName specifies the table name for Invoice
func (Invoice) TableName() string {
	return "invoices"
}

// BeforeCreate hook
func (i *Invoice) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}
