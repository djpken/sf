package service

import (
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// MenuService handles menu-related business logic
type MenuService struct {
	menuRepo *postgres.MenuRepository
}

// NewMenuService creates a new menu service
func NewMenuService(menuRepo *postgres.MenuRepository) *MenuService {
	return &MenuService{
		menuRepo: menuRepo,
	}
}

// === Category DTOs ===

// CreateCategoryRequest represents a request to create a category
type CreateCategoryRequest struct {
	Name      string `json:"name" binding:"required,min=1,max=50"`
	SortOrder int    `json:"sort_order"`
}

// UpdateCategoryRequest represents a request to update a category
type UpdateCategoryRequest struct {
	Name      *string `json:"name,omitempty"`
	SortOrder *int    `json:"sort_order,omitempty"`
	IsActive  *bool   `json:"is_active,omitempty"`
}

// === Menu Item DTOs ===

// CreateMenuItemRequest represents a request to create a menu item
type CreateMenuItemRequest struct {
	CategoryID  *uuid.UUID     `json:"category_id,omitempty"`
	Name        string         `json:"name" binding:"required,min=1,max=100"`
	Description string         `json:"description,omitempty"`
	Price       float64        `json:"price" binding:"required,gt=0"`
	Cost        *float64       `json:"cost,omitempty"`
	ImageURL    string         `json:"image_url,omitempty"`
	Barcode     string         `json:"barcode,omitempty"`
	Options     map[string]any `json:"options,omitempty"`
	TaxType     string         `json:"tax_type,omitempty"`
	SortOrder   int            `json:"sort_order"`
}

// UpdateMenuItemRequest represents a request to update a menu item
type UpdateMenuItemRequest struct {
	CategoryID  *uuid.UUID     `json:"category_id,omitempty"`
	Name        *string        `json:"name,omitempty"`
	Description *string        `json:"description,omitempty"`
	Price       *float64       `json:"price,omitempty"`
	Cost        *float64       `json:"cost,omitempty"`
	ImageURL    *string        `json:"image_url,omitempty"`
	Barcode     *string        `json:"barcode,omitempty"`
	Options     map[string]any `json:"options,omitempty"`
	TaxType     *string        `json:"tax_type,omitempty"`
	SortOrder   *int           `json:"sort_order,omitempty"`
	IsActive    *bool          `json:"is_active,omitempty"`
}

// === Category Methods ===

// ListCategories lists all categories for a tenant
func (s *MenuService) ListCategories(tenantID uuid.UUID, includeInactive bool) ([]domain.MenuCategory, error) {
	return s.menuRepo.ListCategories(tenantID, includeInactive)
}

// GetCategory gets a category by ID
func (s *MenuService) GetCategory(id uuid.UUID) (*domain.MenuCategory, error) {
	category, err := s.menuRepo.FindCategoryByID(id)
	if err != nil {
		return nil, err
	}
	if category == nil {
		return nil, errors.New("category not found")
	}
	return category, nil
}

// CreateCategory creates a new category
func (s *MenuService) CreateCategory(tenantID uuid.UUID, req CreateCategoryRequest) (*domain.MenuCategory, error) {
	category := &domain.MenuCategory{
		TenantID:  tenantID,
		Name:      req.Name,
		SortOrder: req.SortOrder,
		IsActive:  true,
	}

	if err := s.menuRepo.CreateCategory(category); err != nil {
		return nil, err
	}

	return category, nil
}

// UpdateCategory updates a category
func (s *MenuService) UpdateCategory(id uuid.UUID, req UpdateCategoryRequest) (*domain.MenuCategory, error) {
	category, err := s.menuRepo.FindCategoryByID(id)
	if err != nil {
		return nil, err
	}
	if category == nil {
		return nil, errors.New("category not found")
	}

	// Update fields if provided
	if req.Name != nil {
		category.Name = *req.Name
	}
	if req.SortOrder != nil {
		category.SortOrder = *req.SortOrder
	}
	if req.IsActive != nil {
		category.IsActive = *req.IsActive
	}

	if err := s.menuRepo.UpdateCategory(category); err != nil {
		return nil, err
	}

	return category, nil
}

// DeleteCategory soft deletes a category
func (s *MenuService) DeleteCategory(id uuid.UUID) error {
	category, err := s.menuRepo.FindCategoryByID(id)
	if err != nil {
		return err
	}
	if category == nil {
		return errors.New("category not found")
	}

	return s.menuRepo.DeleteCategory(id)
}

// === Menu Item Methods ===

// ListMenuItems lists menu items with optional filters
func (s *MenuService) ListMenuItems(tenantID uuid.UUID, categoryID *uuid.UUID, includeInactive bool) ([]domain.MenuItem, error) {
	return s.menuRepo.ListItems(tenantID, categoryID, includeInactive)
}

// GetMenuItem gets a menu item by ID
func (s *MenuService) GetMenuItem(id uuid.UUID) (*domain.MenuItem, error) {
	item, err := s.menuRepo.FindItemByID(id)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, errors.New("menu item not found")
	}
	return item, nil
}

// GetMenuItemByBarcode gets a menu item by barcode
func (s *MenuService) GetMenuItemByBarcode(tenantID uuid.UUID, barcode string) (*domain.MenuItem, error) {
	item, err := s.menuRepo.FindItemByBarcode(tenantID, barcode)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, fmt.Errorf("menu item with barcode %s not found", barcode)
	}
	return item, nil
}

// CreateMenuItem creates a new menu item
func (s *MenuService) CreateMenuItem(tenantID uuid.UUID, req CreateMenuItemRequest) (*domain.MenuItem, error) {
	// Validate category exists if provided
	if req.CategoryID != nil {
		category, err := s.menuRepo.FindCategoryByID(*req.CategoryID)
		if err != nil {
			return nil, err
		}
		if category == nil {
			return nil, errors.New("category not found")
		}
	}

	item := &domain.MenuItem{
		TenantID:    tenantID,
		CategoryID:  req.CategoryID,
		Name:        req.Name,
		Description: req.Description,
		Price:       req.Price,
		Cost:        req.Cost,
		ImageURL:    req.ImageURL,
		Barcode:     req.Barcode,
		Options:     req.Options,
		TaxType:     req.TaxType,
		SortOrder:   req.SortOrder,
		IsActive:    true,
	}

	if err := s.menuRepo.CreateItem(item); err != nil {
		return nil, err
	}

	// Reload to get relations
	return s.menuRepo.FindItemByID(item.ID)
}

// UpdateMenuItem updates a menu item
func (s *MenuService) UpdateMenuItem(id uuid.UUID, req UpdateMenuItemRequest) (*domain.MenuItem, error) {
	item, err := s.menuRepo.FindItemByID(id)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, errors.New("menu item not found")
	}

	// Validate category if provided
	if req.CategoryID != nil {
		category, err := s.menuRepo.FindCategoryByID(*req.CategoryID)
		if err != nil {
			return nil, err
		}
		if category == nil {
			return nil, errors.New("category not found")
		}
		item.CategoryID = req.CategoryID
	}

	// Update fields if provided
	if req.Name != nil {
		item.Name = *req.Name
	}
	if req.Description != nil {
		item.Description = *req.Description
	}
	if req.Price != nil {
		item.Price = *req.Price
	}
	if req.Cost != nil {
		item.Cost = req.Cost
	}
	if req.ImageURL != nil {
		item.ImageURL = *req.ImageURL
	}
	if req.Barcode != nil {
		item.Barcode = *req.Barcode
	}
	if req.Options != nil {
		item.Options = req.Options
	}
	if req.TaxType != nil {
		item.TaxType = *req.TaxType
	}
	if req.SortOrder != nil {
		item.SortOrder = *req.SortOrder
	}
	if req.IsActive != nil {
		item.IsActive = *req.IsActive
	}

	if err := s.menuRepo.UpdateItem(item); err != nil {
		return nil, err
	}

	// Reload to get relations
	return s.menuRepo.FindItemByID(id)
}

// DeleteMenuItem soft deletes a menu item
func (s *MenuService) DeleteMenuItem(id uuid.UUID) error {
	item, err := s.menuRepo.FindItemByID(id)
	if err != nil {
		return err
	}
	if item == nil {
		return errors.New("menu item not found")
	}

	return s.menuRepo.DeleteItem(id)
}

// === Menu Item Price Methods ===

// SetItemPriceRequest represents a request to set item price
type SetItemPriceRequest struct {
	Price float64 `json:"price" binding:"required,gt=0"`
}

// SetItemPrice sets the price for an item at a specific store
func (s *MenuService) SetItemPrice(itemID, storeID uuid.UUID, price float64) (*domain.MenuItemPrice, error) {
	// Verify item exists
	item, err := s.menuRepo.FindItemByID(itemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, errors.New("menu item not found")
	}

	itemPrice := &domain.MenuItemPrice{
		ItemID:  itemID,
		StoreID: storeID,
		Price:   price,
	}

	if err := s.menuRepo.SetItemPrice(itemPrice); err != nil {
		return nil, err
	}

	return s.menuRepo.GetItemPrice(itemID, storeID)
}

// GetItemPrice gets the price for an item at a store
func (s *MenuService) GetItemPrice(itemID, storeID uuid.UUID) (*domain.MenuItemPrice, error) {
	price, err := s.menuRepo.GetItemPrice(itemID, storeID)
	if err != nil {
		return nil, err
	}
	if price == nil {
		// Return default price from item
		item, err := s.menuRepo.FindItemByID(itemID)
		if err != nil {
			return nil, err
		}
		if item == nil {
			return nil, errors.New("menu item not found")
		}
		// Return a virtual price object
		return &domain.MenuItemPrice{
			ItemID:  itemID,
			StoreID: storeID,
			Price:   item.Price,
		}, nil
	}
	return price, nil
}

// ListItemPrices lists all prices for an item
func (s *MenuService) ListItemPrices(itemID uuid.UUID) ([]domain.MenuItemPrice, error) {
	return s.menuRepo.ListItemPrices(itemID)
}
