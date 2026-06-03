package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TableStatus represents the status of a table
type TableStatus string

const (
	TableStatusAvailable TableStatus = "available"
	TableStatusOccupied  TableStatus = "occupied"
	TableStatusReserved  TableStatus = "reserved"
)

// Table represents a dining table in a store
type Table struct {
	ID        uuid.UUID   `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID   uuid.UUID   `gorm:"type:uuid;not null" json:"store_id"`
	Name      string      `gorm:"type:varchar(20);not null" json:"name"`
	Capacity  int         `json:"capacity,omitempty"`
	Area      string      `gorm:"type:varchar(50)" json:"area,omitempty"`
	Status    TableStatus `gorm:"type:varchar(20);default:'available'" json:"status"`
	CreatedAt time.Time   `json:"created_at"`
	UpdatedAt time.Time   `json:"updated_at"`

	// Relations
	Store *Store `gorm:"foreignKey:StoreID" json:"store,omitempty"`
}

// TableName specifies the table name for Table
func (Table) TableName() string {
	return "tables"
}

// BeforeCreate hook
func (t *Table) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}
