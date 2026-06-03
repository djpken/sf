package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Inventory represents inventory for menu items in a store
type Inventory struct {
	ID                 uuid.UUID  `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID            uuid.UUID  `gorm:"type:uuid;not null" json:"store_id"`
	ItemID             uuid.UUID  `gorm:"type:uuid;not null" json:"item_id"`
	Quantity           float64    `gorm:"type:decimal(10,2);not null;default:0" json:"quantity"`
	Unit               string     `gorm:"type:varchar(20)" json:"unit,omitempty"`
	LowStockThreshold  *float64   `gorm:"type:decimal(10,2)" json:"low_stock_threshold,omitempty"`
	UpdatedAt          time.Time  `json:"updated_at"`

	// Relations
	Store *Store    `gorm:"foreignKey:StoreID" json:"store,omitempty"`
	Item  *MenuItem `gorm:"foreignKey:ItemID" json:"item,omitempty"`
}

// TableName specifies the table name for Inventory
func (Inventory) TableName() string {
	return "inventory"
}

// BeforeCreate hook
func (i *Inventory) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}

// IsLowStock checks if the inventory is below the threshold
func (i *Inventory) IsLowStock() bool {
	if i.LowStockThreshold != nil {
		return i.Quantity <= *i.LowStockThreshold
	}
	return false
}
