package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type WarehouseStoreArea string

const (
	WarehouseStoreAreaFront WarehouseStoreArea = "front"
	WarehouseStoreAreaBack  WarehouseStoreArea = "back"
	WarehouseStoreAreaBoth  WarehouseStoreArea = "both"
)

type WarehouseMeasurementType string

const (
	WarehouseMeasurementWeight   WarehouseMeasurementType = "weight"
	WarehouseMeasurementQuantity WarehouseMeasurementType = "quantity"
	WarehouseMeasurementVolume   WarehouseMeasurementType = "volume"
)

type WarehouseZoneTemplate struct {
	ID        uuid.UUID          `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID   uuid.UUID          `gorm:"type:uuid;not null;index" json:"store_id"`
	StoreArea WarehouseStoreArea `gorm:"type:varchar(20);not null;index" json:"store_area"`
	Name      string             `gorm:"type:varchar(100);not null" json:"name"`
	IsActive  bool               `gorm:"default:true;index" json:"is_active"`
	CreatedAt time.Time          `json:"created_at"`
	UpdatedAt time.Time          `json:"updated_at"`
}

func (WarehouseZoneTemplate) TableName() string { return "warehouse_zone_templates" }

func (z *WarehouseZoneTemplate) BeforeCreate(tx *gorm.DB) error {
	if z.ID == uuid.Nil {
		z.ID = uuid.New()
	}
	return nil
}

type WarehouseTareContainer struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID   uuid.UUID `gorm:"type:uuid;not null;index" json:"store_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Grams     int       `gorm:"not null" json:"grams"`
	IsActive  bool      `gorm:"default:true;index" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (WarehouseTareContainer) TableName() string { return "warehouse_tare_containers" }

func (t *WarehouseTareContainer) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}

type MonthlyInventoryRecord struct {
	ID          uuid.UUID              `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	StoreID     uuid.UUID              `gorm:"type:uuid;not null;index" json:"store_id"`
	StoreArea   WarehouseStoreArea     `gorm:"type:varchar(20);not null;uniqueIndex:idx_monthly_inventory_record" json:"store_area"`
	YearMonth   string                 `gorm:"type:varchar(7);not null;uniqueIndex:idx_monthly_inventory_record" json:"year_month"`
	IsCompleted bool                   `gorm:"default:false" json:"is_completed"`
	Zones       []MonthlyInventoryZone `gorm:"foreignKey:RecordID" json:"zones,omitempty"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

func (MonthlyInventoryRecord) TableName() string { return "monthly_inventory_records" }

func (r *MonthlyInventoryRecord) BeforeCreate(tx *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return nil
}

type MonthlyInventoryZone struct {
	ID             uuid.UUID              `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	RecordID       uuid.UUID              `gorm:"type:uuid;not null;index" json:"record_id"`
	ZoneTemplateID *uuid.UUID             `gorm:"type:uuid;index" json:"zone_template_id,omitempty"`
	NameSnapshot   string                 `gorm:"type:varchar(100);not null" json:"name_snapshot"`
	Items          []MonthlyInventoryItem `gorm:"foreignKey:ZoneID" json:"items,omitempty"`
	CreatedAt      time.Time              `json:"created_at"`
	UpdatedAt      time.Time              `json:"updated_at"`
}

func (MonthlyInventoryZone) TableName() string { return "monthly_inventory_zones" }

func (z *MonthlyInventoryZone) BeforeCreate(tx *gorm.DB) error {
	if z.ID == uuid.Nil {
		z.ID = uuid.New()
	}
	return nil
}

type MonthlyInventoryItem struct {
	ID              uuid.UUID                `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	ZoneID          uuid.UUID                `gorm:"type:uuid;not null;index" json:"zone_id"`
	Name            string                   `gorm:"type:varchar(100);not null" json:"name"`
	MeasurementType WarehouseMeasurementType `gorm:"type:varchar(20);not null" json:"measurement_type"`
	Value           float64                  `gorm:"type:decimal(10,3);not null" json:"value"`
	Note            *string                  `gorm:"type:text" json:"note,omitempty"`
	CreatedAt       time.Time                `json:"created_at"`
	UpdatedAt       time.Time                `json:"updated_at"`
}

func (MonthlyInventoryItem) TableName() string { return "monthly_inventory_items" }

func (i *MonthlyInventoryItem) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}
