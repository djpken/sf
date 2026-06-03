package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MenuCategory represents a menu category
type MenuCategory struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	TenantID  uuid.UUID `gorm:"type:uuid;not null" json:"tenant_id"`
	Name      string    `gorm:"type:varchar(50);not null" json:"name"`
	SortOrder int       `gorm:"default:0" json:"sort_order"`
	IsActive  bool      `gorm:"default:true" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	Tenant *Tenant `gorm:"foreignKey:TenantID" json:"tenant,omitempty"`
}

// TableName specifies the table name for MenuCategory
func (MenuCategory) TableName() string {
	return "menu_categories"
}

// BeforeCreate hook
func (c *MenuCategory) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

// MenuItem represents a menu item/product
type MenuItem struct {
	ID          uuid.UUID      `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	TenantID    uuid.UUID      `gorm:"type:uuid;not null" json:"tenant_id"`
	CategoryID  *uuid.UUID     `gorm:"type:uuid" json:"category_id,omitempty"`
	Name        string         `gorm:"type:varchar(100);not null" json:"name"`
	Description string         `gorm:"type:text" json:"description,omitempty"`
	Price       float64        `gorm:"type:decimal(10,2);not null" json:"price"`
	Cost        *float64       `gorm:"type:decimal(10,2)" json:"cost,omitempty"`
	ImageURL    string         `gorm:"type:text" json:"image_url,omitempty"`
	Barcode     string         `gorm:"type:varchar(50)" json:"barcode,omitempty"`
	IsActive    bool           `gorm:"default:true" json:"is_active"`
	Options     map[string]any `gorm:"type:jsonb" json:"options,omitempty"`
	TaxType     string         `gorm:"type:varchar(20)" json:"tax_type,omitempty"`
	SortOrder   int            `gorm:"default:0" json:"sort_order"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`

	// Relations
	Tenant   *Tenant       `gorm:"foreignKey:TenantID" json:"tenant,omitempty"`
	Category *MenuCategory `gorm:"foreignKey:CategoryID" json:"category,omitempty"`
}

// TableName specifies the table name for MenuItem
func (MenuItem) TableName() string {
	return "menu_items"
}

// BeforeCreate hook
func (i *MenuItem) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}

// MenuItemPrice represents store-specific pricing for menu items
type MenuItemPrice struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	ItemID    uuid.UUID `gorm:"type:uuid;not null" json:"item_id"`
	StoreID   uuid.UUID `gorm:"type:uuid;not null" json:"store_id"`
	Price     float64   `gorm:"type:decimal(10,2);not null" json:"price"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	Item  *MenuItem `gorm:"foreignKey:ItemID" json:"item,omitempty"`
	Store *Store    `gorm:"foreignKey:StoreID" json:"store,omitempty"`
}

// TableName specifies the table name for MenuItemPrice
func (MenuItemPrice) TableName() string {
	return "menu_item_prices"
}

// BeforeCreate hook
func (p *MenuItemPrice) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}
