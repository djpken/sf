package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// EmployeeRole represents the role of an employee
type EmployeeRole string

const (
	RoleAdmin   EmployeeRole = "admin"
	RoleManager EmployeeRole = "manager"
	RoleCashier EmployeeRole = "cashier"
	RoleKitchen EmployeeRole = "kitchen"
)

// Employee represents an employee in the system
type Employee struct {
	ID           uuid.UUID      `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	TenantID     uuid.UUID      `gorm:"type:uuid;not null" json:"tenant_id"`
	StoreID      *uuid.UUID     `gorm:"type:uuid" json:"store_id,omitempty"`
	Name         string         `gorm:"type:varchar(50);not null" json:"name"`
	Email        string         `gorm:"type:varchar(100)" json:"email,omitempty"`
	PinCode      string         `gorm:"type:varchar(10)" json:"pin_code,omitempty"`
	PasswordHash string         `gorm:"type:varchar(255)" json:"-"`
	Role         EmployeeRole   `gorm:"type:varchar(20);not null" json:"role"`
	Permissions  map[string]any `gorm:"type:jsonb" json:"permissions,omitempty"`
	IsActive     bool           `gorm:"default:true" json:"is_active"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`

	// Relations
	Tenant *Tenant `gorm:"foreignKey:TenantID" json:"tenant,omitempty"`
	Store  *Store  `gorm:"foreignKey:StoreID" json:"store,omitempty"`
}

// TableName specifies the table name for Employee
func (Employee) TableName() string {
	return "employees"
}

// BeforeCreate hook
func (e *Employee) BeforeCreate(tx *gorm.DB) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	return nil
}
