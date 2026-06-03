package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Tenant represents a tenant/brand in the system
type Tenant struct {
	ID            uuid.UUID      `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	Name          string         `gorm:"type:varchar(100);not null" json:"name"`
	TaxID         string         `gorm:"type:varchar(20)" json:"tax_id,omitempty"`
	InvoiceConfig map[string]any `gorm:"type:jsonb" json:"invoice_config,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
}

// TableName specifies the table name for Tenant
func (Tenant) TableName() string {
	return "tenants"
}

// BeforeCreate hook
func (t *Tenant) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}
