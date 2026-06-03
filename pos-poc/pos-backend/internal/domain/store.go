package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Store represents a store/branch in the system
type Store struct {
	ID        uuid.UUID      `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	TenantID  uuid.UUID      `gorm:"type:uuid;not null" json:"tenant_id"`
	Name      string         `gorm:"type:varchar(100);not null" json:"name"`
	Address   string         `gorm:"type:text" json:"address,omitempty"`
	Phone     string         `gorm:"type:varchar(20)" json:"phone,omitempty"`
	IsActive  bool           `gorm:"default:true" json:"is_active"`
	Settings  map[string]any `gorm:"type:jsonb" json:"settings,omitempty"`
	CreatedAt time.Time      `json:"created_at"`
	UpdatedAt time.Time      `json:"updated_at"`

	// Relations
	Tenant *Tenant `gorm:"foreignKey:TenantID" json:"tenant,omitempty"`
}

// TableName specifies the table name for Store
func (Store) TableName() string {
	return "stores"
}

// BeforeCreate hook
func (s *Store) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}
