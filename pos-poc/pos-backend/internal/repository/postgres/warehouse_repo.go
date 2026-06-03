package postgres

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

type WarehouseRepository struct {
	db *gorm.DB
}

func NewWarehouseRepository(db *gorm.DB) *WarehouseRepository {
	return &WarehouseRepository{db: db}
}

func (r *WarehouseRepository) ListZoneTemplates(storeID uuid.UUID, storeArea domain.WarehouseStoreArea) ([]domain.WarehouseZoneTemplate, error) {
	var templates []domain.WarehouseZoneTemplate
	err := r.db.Where("store_id = ? AND store_area = ? AND is_active = true", storeID, storeArea).
		Order("created_at ASC").
		Find(&templates).Error
	return templates, err
}

func (r *WarehouseRepository) CreateZoneTemplate(template *domain.WarehouseZoneTemplate) error {
	return r.db.Create(template).Error
}

func (r *WarehouseRepository) FindZoneTemplate(storeID, id uuid.UUID) (*domain.WarehouseZoneTemplate, error) {
	var template domain.WarehouseZoneTemplate
	err := r.db.Where("store_id = ? AND id = ?", storeID, id).First(&template).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &template, nil
}

func (r *WarehouseRepository) UpdateZoneTemplate(template *domain.WarehouseZoneTemplate) error {
	return r.db.Save(template).Error
}

func (r *WarehouseRepository) ListTareContainers(storeID uuid.UUID) ([]domain.WarehouseTareContainer, error) {
	var containers []domain.WarehouseTareContainer
	err := r.db.Where("store_id = ? AND is_active = true", storeID).
		Order("created_at ASC").
		Find(&containers).Error
	return containers, err
}

func (r *WarehouseRepository) CreateTareContainer(container *domain.WarehouseTareContainer) error {
	return r.db.Create(container).Error
}

func (r *WarehouseRepository) FindTareContainer(storeID, id uuid.UUID) (*domain.WarehouseTareContainer, error) {
	var container domain.WarehouseTareContainer
	err := r.db.Where("store_id = ? AND id = ?", storeID, id).First(&container).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &container, nil
}

func (r *WarehouseRepository) UpdateTareContainer(container *domain.WarehouseTareContainer) error {
	return r.db.Save(container).Error
}

func (r *WarehouseRepository) LoadOrCreateMonthlyRecord(storeID uuid.UUID, storeArea domain.WarehouseStoreArea, yearMonth string) (*domain.MonthlyInventoryRecord, error) {
	var record domain.MonthlyInventoryRecord
	err := r.db.Transaction(func(tx *gorm.DB) error {
		findErr := tx.
			Preload("Zones.Items", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
			Preload("Zones", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
			Where("store_id = ? AND store_area = ? AND year_month = ?", storeID, storeArea, yearMonth).
			First(&record).Error

		if errors.Is(findErr, gorm.ErrRecordNotFound) {
			record = domain.MonthlyInventoryRecord{
				StoreID:   storeID,
				StoreArea: storeArea,
				YearMonth: yearMonth,
			}
			if err := tx.Create(&record).Error; err != nil {
				return err
			}
		} else if findErr != nil {
			return findErr
		}

		var templates []domain.WarehouseZoneTemplate
		if err := tx.Where("store_id = ? AND store_area = ? AND is_active = true", storeID, storeArea).
			Order("created_at ASC").
			Find(&templates).Error; err != nil {
			return err
		}

		existingTemplateZones := map[uuid.UUID]bool{}
		for _, zone := range record.Zones {
			if zone.ZoneTemplateID != nil {
				existingTemplateZones[*zone.ZoneTemplateID] = true
			}
		}

		for _, template := range templates {
			if existingTemplateZones[template.ID] {
				continue
			}
			zone := domain.MonthlyInventoryZone{
				RecordID:       record.ID,
				ZoneTemplateID: &template.ID,
				NameSnapshot:   template.Name,
			}
			if err := tx.Create(&zone).Error; err != nil {
				return err
			}
		}

		return tx.
			Preload("Zones.Items", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
			Preload("Zones", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
			Where("id = ?", record.ID).
			First(&record).Error
	})
	if err != nil {
		return nil, err
	}
	return &record, nil
}

func (r *WarehouseRepository) FindMonthlyRecord(storeID, id uuid.UUID) (*domain.MonthlyInventoryRecord, error) {
	var record domain.MonthlyInventoryRecord
	err := r.db.
		Preload("Zones.Items", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
		Preload("Zones", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
		Where("store_id = ? AND id = ?", storeID, id).
		First(&record).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &record, nil
}

func (r *WarehouseRepository) CompleteMonthlyRecord(record *domain.MonthlyInventoryRecord) error {
	return r.db.Model(record).Update("is_completed", true).Error
}

func (r *WarehouseRepository) FindMonthlyZoneByStore(storeID, zoneID uuid.UUID) (*domain.MonthlyInventoryZone, error) {
	var zone domain.MonthlyInventoryZone
	err := r.db.
		Joins("JOIN monthly_inventory_records ON monthly_inventory_records.id = monthly_inventory_zones.record_id").
		Where("monthly_inventory_records.store_id = ? AND monthly_inventory_zones.id = ?", storeID, zoneID).
		First(&zone).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &zone, nil
}

func (r *WarehouseRepository) CreateMonthlyItem(item *domain.MonthlyInventoryItem) error {
	return r.db.Create(item).Error
}

func (r *WarehouseRepository) FindMonthlyItemByStore(storeID, itemID uuid.UUID) (*domain.MonthlyInventoryItem, error) {
	var item domain.MonthlyInventoryItem
	err := r.db.
		Joins("JOIN monthly_inventory_zones ON monthly_inventory_zones.id = monthly_inventory_items.zone_id").
		Joins("JOIN monthly_inventory_records ON monthly_inventory_records.id = monthly_inventory_zones.record_id").
		Where("monthly_inventory_records.store_id = ? AND monthly_inventory_items.id = ?", storeID, itemID).
		First(&item).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &item, nil
}

func (r *WarehouseRepository) UpdateMonthlyItem(item *domain.MonthlyInventoryItem) error {
	return r.db.Save(item).Error
}

func (r *WarehouseRepository) DeleteMonthlyItem(item *domain.MonthlyInventoryItem) error {
	return r.db.Delete(item).Error
}
