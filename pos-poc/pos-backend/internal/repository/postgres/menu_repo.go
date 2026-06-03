package postgres

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

// MenuRepository handles menu-related data access
type MenuRepository struct {
	db *gorm.DB
}

// NewMenuRepository creates a new menu repository
func NewMenuRepository(db *gorm.DB) *MenuRepository {
	return &MenuRepository{db: db}
}

// === Menu Categories ===

// FindCategoryByID finds a category by ID
func (r *MenuRepository) FindCategoryByID(id uuid.UUID) (*domain.MenuCategory, error) {
	var category domain.MenuCategory
	if err := r.db.Where("id = ?", id).First(&category).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &category, nil
}

// ListCategories lists all categories for a tenant
func (r *MenuRepository) ListCategories(tenantID uuid.UUID, includeInactive bool) ([]domain.MenuCategory, error) {
	var categories []domain.MenuCategory
	query := r.db.Where("tenant_id = ?", tenantID)

	if !includeInactive {
		query = query.Where("is_active = ?", true)
	}

	if err := query.Order("sort_order ASC, name ASC").Find(&categories).Error; err != nil {
		return nil, err
	}
	return categories, nil
}

// CreateCategory creates a new category
func (r *MenuRepository) CreateCategory(category *domain.MenuCategory) error {
	return r.db.Create(category).Error
}

// UpdateCategory updates a category
func (r *MenuRepository) UpdateCategory(category *domain.MenuCategory) error {
	return r.db.Save(category).Error
}

// DeleteCategory soft deletes a category
func (r *MenuRepository) DeleteCategory(id uuid.UUID) error {
	return r.db.Model(&domain.MenuCategory{}).Where("id = ?", id).Update("is_active", false).Error
}

// === Menu Items ===

// FindItemByID finds a menu item by ID
func (r *MenuRepository) FindItemByID(id uuid.UUID) (*domain.MenuItem, error) {
	var item domain.MenuItem
	if err := r.db.Preload("Category").Where("id = ?", id).First(&item).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

// FindItemByBarcode finds a menu item by barcode
func (r *MenuRepository) FindItemByBarcode(tenantID uuid.UUID, barcode string) (*domain.MenuItem, error) {
	var item domain.MenuItem
	if err := r.db.Preload("Category").
		Where("tenant_id = ? AND barcode = ?", tenantID, barcode).
		First(&item).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &item, nil
}

// ListItems lists menu items with optional filters
func (r *MenuRepository) ListItems(tenantID uuid.UUID, categoryID *uuid.UUID, includeInactive bool) ([]domain.MenuItem, error) {
	var items []domain.MenuItem
	query := r.db.Preload("Category").Where("tenant_id = ?", tenantID)

	if categoryID != nil {
		query = query.Where("category_id = ?", *categoryID)
	}

	if !includeInactive {
		query = query.Where("is_active = ?", true)
	}

	if err := query.Order("sort_order ASC, name ASC").Find(&items).Error; err != nil {
		return nil, err
	}
	return items, nil
}

// CreateItem creates a new menu item
func (r *MenuRepository) CreateItem(item *domain.MenuItem) error {
	return r.db.Create(item).Error
}

// UpdateItem updates a menu item
func (r *MenuRepository) UpdateItem(item *domain.MenuItem) error {
	return r.db.Save(item).Error
}

// DeleteItem soft deletes a menu item
func (r *MenuRepository) DeleteItem(id uuid.UUID) error {
	return r.db.Model(&domain.MenuItem{}).Where("id = ?", id).Update("is_active", false).Error
}

// === Menu Item Prices ===

// GetItemPrice gets the price for an item at a specific store
func (r *MenuRepository) GetItemPrice(itemID, storeID uuid.UUID) (*domain.MenuItemPrice, error) {
	var price domain.MenuItemPrice
	if err := r.db.Where("item_id = ? AND store_id = ?", itemID, storeID).First(&price).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &price, nil
}

// SetItemPrice sets or updates the price for an item at a store
func (r *MenuRepository) SetItemPrice(price *domain.MenuItemPrice) error {
	// Upsert: update if exists, create if not
	return r.db.Save(price).Error
}

// ListItemPrices lists all prices for an item across stores
func (r *MenuRepository) ListItemPrices(itemID uuid.UUID) ([]domain.MenuItemPrice, error) {
	var prices []domain.MenuItemPrice
	if err := r.db.Preload("Store").Where("item_id = ?", itemID).Find(&prices).Error; err != nil {
		return nil, err
	}
	return prices, nil
}

// DeleteItemPrice deletes a specific price
func (r *MenuRepository) DeleteItemPrice(itemID, storeID uuid.UUID) error {
	return r.db.Where("item_id = ? AND store_id = ?", itemID, storeID).Delete(&domain.MenuItemPrice{}).Error
}
