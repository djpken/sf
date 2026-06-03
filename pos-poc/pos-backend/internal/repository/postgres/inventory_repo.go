package postgres

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

// InventoryRepository handles inventory-related data access
type InventoryRepository struct {
	db *gorm.DB
}

// NewInventoryRepository creates a new inventory repository
func NewInventoryRepository(db *gorm.DB) *InventoryRepository {
	return &InventoryRepository{db: db}
}

// FindByID finds inventory by ID
func (r *InventoryRepository) FindByID(id uuid.UUID) (*domain.Inventory, error) {
	var inventory domain.Inventory
	if err := r.db.Preload("Item").Preload("Store").Where("id = ?", id).First(&inventory).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &inventory, nil
}

// FindByStoreAndItem finds inventory by store and item
func (r *InventoryRepository) FindByStoreAndItem(storeID, itemID uuid.UUID) (*domain.Inventory, error) {
	var inventory domain.Inventory
	if err := r.db.Preload("Item").
		Where("store_id = ? AND item_id = ?", storeID, itemID).
		First(&inventory).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &inventory, nil
}

// List lists all inventory in a store
func (r *InventoryRepository) List(storeID uuid.UUID, lowStockOnly bool) ([]domain.Inventory, error) {
	var inventories []domain.Inventory
	query := r.db.Preload("Item").Preload("Item.Category").Where("store_id = ?", storeID)

	if lowStockOnly {
		query = query.Where("low_stock_threshold IS NOT NULL AND quantity <= low_stock_threshold")
	}

	if err := query.Order("updated_at DESC").Find(&inventories).Error; err != nil {
		return nil, err
	}
	return inventories, nil
}

// Create creates new inventory
func (r *InventoryRepository) Create(inventory *domain.Inventory) error {
	return r.db.Create(inventory).Error
}

// Update updates inventory
func (r *InventoryRepository) Update(inventory *domain.Inventory) error {
	return r.db.Save(inventory).Error
}

// UpdateQuantity updates inventory quantity
func (r *InventoryRepository) UpdateQuantity(id uuid.UUID, quantity float64) error {
	return r.db.Model(&domain.Inventory{}).
		Where("id = ?", id).
		Update("quantity", quantity).Error
}

// AdjustQuantity adjusts inventory quantity (add or subtract)
func (r *InventoryRepository) AdjustQuantity(id uuid.UUID, adjustment float64) error {
	return r.db.Model(&domain.Inventory{}).
		Where("id = ?", id).
		Update("quantity", gorm.Expr("quantity + ?", adjustment)).Error
}

// Delete deletes inventory
func (r *InventoryRepository) Delete(id uuid.UUID) error {
	return r.db.Delete(&domain.Inventory{}, id).Error
}

// GetLowStockItems gets all low stock items
func (r *InventoryRepository) GetLowStockItems(storeID uuid.UUID) ([]domain.Inventory, error) {
	return r.List(storeID, true)
}

// GetLowStockCount gets count of low stock items
func (r *InventoryRepository) GetLowStockCount(storeID uuid.UUID) (int64, error) {
	var count int64
	if err := r.db.Model(&domain.Inventory{}).
		Where("store_id = ? AND low_stock_threshold IS NOT NULL AND quantity <= low_stock_threshold", storeID).
		Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}

// GetTotalValue gets total inventory value for a store
func (r *InventoryRepository) GetTotalValue(storeID uuid.UUID) (float64, error) {
	type Result struct {
		TotalValue float64
	}

	var result Result
	if err := r.db.Table("inventory").
		Select("COALESCE(SUM(inventory.quantity * menu_items.cost), 0) as total_value").
		Joins("LEFT JOIN menu_items ON inventory.item_id = menu_items.id").
		Where("inventory.store_id = ?", storeID).
		Scan(&result).Error; err != nil {
		return 0, err
	}

	return result.TotalValue, nil
}

// BulkUpdateQuantities updates multiple inventory quantities
func (r *InventoryRepository) BulkUpdateQuantities(updates map[uuid.UUID]float64) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		for id, quantity := range updates {
			if err := tx.Model(&domain.Inventory{}).
				Where("id = ?", id).
				Update("quantity", quantity).Error; err != nil {
				return err
			}
		}
		return nil
	})
}
