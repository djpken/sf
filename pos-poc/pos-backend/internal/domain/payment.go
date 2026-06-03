package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PaymentMethod represents the payment method
type PaymentMethod string

const (
	PaymentMethodCash       PaymentMethod = "cash"
	PaymentMethodCreditCard PaymentMethod = "credit_card"
	PaymentMethodLinePay    PaymentMethod = "line_pay"
	PaymentMethodOther      PaymentMethod = "other"
)

// PaymentStatusEnum represents the payment status
type PaymentStatusEnum string

const (
	PaymentStatusEnumPending   PaymentStatusEnum = "pending"
	PaymentStatusEnumCompleted PaymentStatusEnum = "completed"
	PaymentStatusEnumFailed    PaymentStatusEnum = "failed"
	PaymentStatusEnumRefunded  PaymentStatusEnum = "refunded"
)

// Payment represents a payment record
type Payment struct {
	ID          uuid.UUID         `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	OrderID     uuid.UUID         `gorm:"type:uuid;not null" json:"order_id"`
	Method      PaymentMethod     `gorm:"type:varchar(20);not null" json:"method"`
	Amount      float64           `gorm:"type:decimal(10,2);not null" json:"amount"`
	Received    *float64          `gorm:"type:decimal(10,2)" json:"received,omitempty"`
	Change      *float64          `gorm:"type:decimal(10,2)" json:"change,omitempty"`
	ReferenceNo string            `gorm:"type:varchar(100)" json:"reference_no,omitempty"`
	Status      PaymentStatusEnum `gorm:"type:varchar(20);default:'completed'" json:"status"`
	CreatedAt   time.Time         `json:"created_at"`

	// Relations
	Order *Order `gorm:"foreignKey:OrderID" json:"order,omitempty"`
}

// TableName specifies the table name for Payment
func (Payment) TableName() string {
	return "payments"
}

// BeforeCreate hook
func (p *Payment) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}
