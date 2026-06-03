package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// OrderType represents the type of order
type OrderType string

const (
	OrderTypeDineIn   OrderType = "dine_in"
	OrderTypeTakeout  OrderType = "takeout"
	OrderTypeDelivery OrderType = "delivery"
)

// OrderStatus represents the status of an order
type OrderStatus string

const (
	OrderStatusPending   OrderStatus = "pending"
	OrderStatusPreparing OrderStatus = "preparing"
	OrderStatusReady     OrderStatus = "ready"
	OrderStatusCompleted OrderStatus = "completed"
	OrderStatusCancelled OrderStatus = "cancelled"
)

// PaymentStatus represents the payment status of an order
type PaymentStatus string

const (
	PaymentStatusUnpaid  PaymentStatus = "unpaid"
	PaymentStatusPartial PaymentStatus = "partial"
	PaymentStatusPaid    PaymentStatus = "paid"
	PaymentStatusRefund  PaymentStatus = "refunded"
)

// Order represents an order in the system
type Order struct {
	ID               uuid.UUID     `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID          uuid.UUID     `gorm:"type:uuid;not null" json:"store_id"`
	OrderNo          string        `gorm:"type:varchar(30);not null" json:"order_no"`
	OrderType        OrderType     `gorm:"type:varchar(20);not null" json:"order_type"`
	TableID          *uuid.UUID    `gorm:"type:uuid" json:"table_id,omitempty"`
	CustomerName     string        `gorm:"type:varchar(50)" json:"customer_name,omitempty"`
	CustomerPhone    string        `gorm:"type:varchar(20)" json:"customer_phone,omitempty"`
	DeliveryAddress  string        `gorm:"type:text" json:"delivery_address,omitempty"`
	DeliveryPlatform string        `gorm:"type:varchar(20)" json:"delivery_platform,omitempty"`
	Subtotal         float64       `gorm:"type:decimal(10,2)" json:"subtotal"`
	Discount         float64       `gorm:"type:decimal(10,2);default:0" json:"discount"`
	Tax              float64       `gorm:"type:decimal(10,2)" json:"tax"`
	ServiceCharge    float64       `gorm:"type:decimal(10,2);default:0" json:"service_charge"`
	Total            float64       `gorm:"type:decimal(10,2)" json:"total"`
	Status           OrderStatus   `gorm:"type:varchar(20);default:'pending'" json:"status"`
	PaymentStatus    PaymentStatus `gorm:"type:varchar(20);default:'unpaid'" json:"payment_status"`
	EmployeeID       *uuid.UUID    `gorm:"type:uuid" json:"employee_id,omitempty"`
	Notes            string        `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt        time.Time     `json:"created_at"`
	UpdatedAt        time.Time     `json:"updated_at"`

	// Relations
	Store    *Store       `gorm:"foreignKey:StoreID" json:"store,omitempty"`
	Table    *Table       `gorm:"foreignKey:TableID" json:"table,omitempty"`
	Employee *Employee    `gorm:"foreignKey:EmployeeID" json:"employee,omitempty"`
	Items    []OrderItem  `gorm:"foreignKey:OrderID" json:"items,omitempty"`
	Payments []Payment    `gorm:"foreignKey:OrderID" json:"payments,omitempty"`
	Invoice  *Invoice     `gorm:"foreignKey:OrderID" json:"invoice,omitempty"`
}

// TableName specifies the table name for Order
func (Order) TableName() string {
	return "orders"
}

// BeforeCreate hook
func (o *Order) BeforeCreate(tx *gorm.DB) error {
	if o.ID == uuid.Nil {
		o.ID = uuid.New()
	}
	return nil
}

// OrderItemStatus represents the status of an order item
type OrderItemStatus string

const (
	OrderItemStatusPending   OrderItemStatus = "pending"
	OrderItemStatusPreparing OrderItemStatus = "preparing"
	OrderItemStatusReady     OrderItemStatus = "ready"
	OrderItemStatusServed    OrderItemStatus = "served"
)

// OrderItem represents an item in an order
type OrderItem struct {
	ID        uuid.UUID       `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	OrderID   uuid.UUID       `gorm:"type:uuid;not null" json:"order_id"`
	ItemID    *uuid.UUID      `gorm:"type:uuid" json:"item_id,omitempty"`
	ItemName  string          `gorm:"type:varchar(100);not null" json:"item_name"`
	UnitPrice float64         `gorm:"type:decimal(10,2);not null" json:"unit_price"`
	Quantity  int             `gorm:"not null" json:"quantity"`
	Subtotal  float64         `gorm:"type:decimal(10,2);not null" json:"subtotal"`
	Options   map[string]any  `gorm:"type:jsonb" json:"options,omitempty"`
	Notes     string          `gorm:"type:text" json:"notes,omitempty"`
	Status    OrderItemStatus `gorm:"type:varchar(20);default:'pending'" json:"status"`
	CreatedAt time.Time       `json:"created_at"`
	UpdatedAt time.Time       `json:"updated_at"`

	// Relations
	Order *Order    `gorm:"foreignKey:OrderID" json:"order,omitempty"`
	Item  *MenuItem `gorm:"foreignKey:ItemID" json:"item,omitempty"`
}

// TableName specifies the table name for OrderItem
func (OrderItem) TableName() string {
	return "order_items"
}

// BeforeCreate hook
func (i *OrderItem) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}
