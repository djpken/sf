package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// MenuHandler handles menu-related endpoints
type MenuHandler struct {
	menuService *service.MenuService
}

// NewMenuHandler creates a new menu handler
func NewMenuHandler(menuService *service.MenuService) *MenuHandler {
	return &MenuHandler{
		menuService: menuService,
	}
}

// === Category Handlers ===

// ListCategories lists all menu categories
// @Summary List menu categories
// @Tags menu
// @Produce json
// @Param include_inactive query bool false "Include inactive categories"
// @Success 200 {array} domain.MenuCategory
// @Security BearerAuth
// @Router /menu/categories [get]
func (h *MenuHandler) ListCategories(c *gin.Context) {
	tenantID, _ := c.Get("tenant_id")
	includeInactive := c.Query("include_inactive") == "true"

	categories, err := h.menuService.ListCategories(tenantID.(uuid.UUID), includeInactive)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, categories)
}

// GetCategory gets a category by ID
// @Summary Get category by ID
// @Tags menu
// @Produce json
// @Param id path string true "Category ID"
// @Success 200 {object} domain.MenuCategory
// @Security BearerAuth
// @Router /menu/categories/{id} [get]
func (h *MenuHandler) GetCategory(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid category ID")
		return
	}

	category, err := h.menuService.GetCategory(id)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, category)
}

// CreateCategory creates a new category
// @Summary Create menu category
// @Tags menu
// @Accept json
// @Produce json
// @Param request body service.CreateCategoryRequest true "Category data"
// @Success 200 {object} domain.MenuCategory
// @Security BearerAuth
// @Router /menu/categories [post]
func (h *MenuHandler) CreateCategory(c *gin.Context) {
	tenantID, _ := c.Get("tenant_id")

	var req service.CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	category, err := h.menuService.CreateCategory(tenantID.(uuid.UUID), req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Category created successfully", category)
}

// UpdateCategory updates a category
// @Summary Update menu category
// @Tags menu
// @Accept json
// @Produce json
// @Param id path string true "Category ID"
// @Param request body service.UpdateCategoryRequest true "Category data"
// @Success 200 {object} domain.MenuCategory
// @Security BearerAuth
// @Router /menu/categories/{id} [put]
func (h *MenuHandler) UpdateCategory(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid category ID")
		return
	}

	var req service.UpdateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	category, err := h.menuService.UpdateCategory(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Category updated successfully", category)
}

// DeleteCategory deletes a category
// @Summary Delete menu category
// @Tags menu
// @Produce json
// @Param id path string true "Category ID"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /menu/categories/{id} [delete]
func (h *MenuHandler) DeleteCategory(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid category ID")
		return
	}

	if err := h.menuService.DeleteCategory(id); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Category deleted successfully", nil)
}

// === Menu Item Handlers ===

// ListMenuItems lists menu items
// @Summary List menu items
// @Tags menu
// @Produce json
// @Param category_id query string false "Filter by category ID"
// @Param include_inactive query bool false "Include inactive items"
// @Success 200 {array} domain.MenuItem
// @Security BearerAuth
// @Router /menu/items [get]
func (h *MenuHandler) ListMenuItems(c *gin.Context) {
	tenantID, _ := c.Get("tenant_id")
	includeInactive := c.Query("include_inactive") == "true"

	var categoryID *uuid.UUID
	if catID := c.Query("category_id"); catID != "" {
		id, err := uuid.Parse(catID)
		if err != nil {
			utils.BadRequestResponse(c, "Invalid category ID")
			return
		}
		categoryID = &id
	}

	items, err := h.menuService.ListMenuItems(tenantID.(uuid.UUID), categoryID, includeInactive)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, items)
}

// GetMenuItem gets a menu item by ID
// @Summary Get menu item by ID
// @Tags menu
// @Produce json
// @Param id path string true "Item ID"
// @Success 200 {object} domain.MenuItem
// @Security BearerAuth
// @Router /menu/items/{id} [get]
func (h *MenuHandler) GetMenuItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	item, err := h.menuService.GetMenuItem(id)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, item)
}

// GetMenuItemByBarcode gets a menu item by barcode
// @Summary Get menu item by barcode
// @Tags menu
// @Produce json
// @Param barcode path string true "Barcode"
// @Success 200 {object} domain.MenuItem
// @Security BearerAuth
// @Router /menu/items/barcode/{barcode} [get]
func (h *MenuHandler) GetMenuItemByBarcode(c *gin.Context) {
	tenantID, _ := c.Get("tenant_id")
	barcode := c.Param("barcode")

	item, err := h.menuService.GetMenuItemByBarcode(tenantID.(uuid.UUID), barcode)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, item)
}

// CreateMenuItem creates a new menu item
// @Summary Create menu item
// @Tags menu
// @Accept json
// @Produce json
// @Param request body service.CreateMenuItemRequest true "Item data"
// @Success 200 {object} domain.MenuItem
// @Security BearerAuth
// @Router /menu/items [post]
func (h *MenuHandler) CreateMenuItem(c *gin.Context) {
	tenantID, _ := c.Get("tenant_id")

	var req service.CreateMenuItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	item, err := h.menuService.CreateMenuItem(tenantID.(uuid.UUID), req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Menu item created successfully", item)
}

// UpdateMenuItem updates a menu item
// @Summary Update menu item
// @Tags menu
// @Accept json
// @Produce json
// @Param id path string true "Item ID"
// @Param request body service.UpdateMenuItemRequest true "Item data"
// @Success 200 {object} domain.MenuItem
// @Security BearerAuth
// @Router /menu/items/{id} [put]
func (h *MenuHandler) UpdateMenuItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	var req service.UpdateMenuItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	item, err := h.menuService.UpdateMenuItem(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Menu item updated successfully", item)
}

// DeleteMenuItem deletes a menu item
// @Summary Delete menu item
// @Tags menu
// @Produce json
// @Param id path string true "Item ID"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /menu/items/{id} [delete]
func (h *MenuHandler) DeleteMenuItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	if err := h.menuService.DeleteMenuItem(id); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Menu item deleted successfully", nil)
}

// === Item Price Handlers ===

// SetItemPrice sets the price for an item at a store
// @Summary Set item price for store
// @Tags menu
// @Accept json
// @Produce json
// @Param id path string true "Item ID"
// @Param store_id path string true "Store ID"
// @Param request body service.SetItemPriceRequest true "Price data"
// @Success 200 {object} domain.MenuItemPrice
// @Security BearerAuth
// @Router /menu/items/{id}/prices/{store_id} [put]
func (h *MenuHandler) SetItemPrice(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	storeID, err := uuid.Parse(c.Param("store_id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid store ID")
		return
	}

	var req service.SetItemPriceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	price, err := h.menuService.SetItemPrice(itemID, storeID, req.Price)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Price updated successfully", price)
}

// GetItemPrice gets the price for an item at a store
// @Summary Get item price for store
// @Tags menu
// @Produce json
// @Param id path string true "Item ID"
// @Param store_id path string true "Store ID"
// @Success 200 {object} domain.MenuItemPrice
// @Security BearerAuth
// @Router /menu/items/{id}/prices/{store_id} [get]
func (h *MenuHandler) GetItemPrice(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	storeID, err := uuid.Parse(c.Param("store_id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid store ID")
		return
	}

	price, err := h.menuService.GetItemPrice(itemID, storeID)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, price)
}

// ListItemPrices lists all prices for an item
// @Summary List item prices across stores
// @Tags menu
// @Produce json
// @Param id path string true "Item ID"
// @Success 200 {array} domain.MenuItemPrice
// @Security BearerAuth
// @Router /menu/items/{id}/prices [get]
func (h *MenuHandler) ListItemPrices(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid item ID")
		return
	}

	prices, err := h.menuService.ListItemPrices(itemID)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, prices)
}
