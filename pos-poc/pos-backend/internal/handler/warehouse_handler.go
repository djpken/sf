package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

type WarehouseHandler struct {
	warehouseService *service.WarehouseService
}

func NewWarehouseHandler(warehouseService *service.WarehouseService) *WarehouseHandler {
	return &WarehouseHandler{warehouseService: warehouseService}
}

func (h *WarehouseHandler) ListZoneTemplates(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	templates, err := h.warehouseService.ListZoneTemplates(storeID, domain.WarehouseStoreArea(c.Query("store_area")))
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessResponse(c, templates)
}

func (h *WarehouseHandler) CreateZoneTemplate(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	var req service.ZoneTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	template, err := h.warehouseService.CreateZoneTemplate(storeID, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Zone template created successfully", template)
}

func (h *WarehouseHandler) UpdateZoneTemplate(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	var req service.UpdateZoneTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	template, err := h.warehouseService.UpdateZoneTemplate(storeID, id, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Zone template updated successfully", template)
}

func (h *WarehouseHandler) DeleteZoneTemplate(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	if err := h.warehouseService.DeleteZoneTemplate(storeID, id); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Zone template deleted successfully", nil)
}

func (h *WarehouseHandler) ListTareContainers(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	containers, err := h.warehouseService.ListTareContainers(storeID)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}
	utils.SuccessResponse(c, containers)
}

func (h *WarehouseHandler) CreateTareContainer(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	var req service.TareContainerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	container, err := h.warehouseService.CreateTareContainer(storeID, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Tare container created successfully", container)
}

func (h *WarehouseHandler) UpdateTareContainer(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	var req service.UpdateTareContainerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	container, err := h.warehouseService.UpdateTareContainer(storeID, id, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Tare container updated successfully", container)
}

func (h *WarehouseHandler) DeleteTareContainer(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	if err := h.warehouseService.DeleteTareContainer(storeID, id); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Tare container deleted successfully", nil)
}

func (h *WarehouseHandler) GetMonthlyRecord(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	record, err := h.warehouseService.LoadOrCreateMonthlyRecord(
		storeID,
		domain.WarehouseStoreArea(c.Query("store_area")),
		c.Query("year_month"),
	)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessResponse(c, record)
}

func (h *WarehouseHandler) CompleteMonthlyRecord(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	record, err := h.warehouseService.CompleteMonthlyRecord(storeID, id)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Monthly inventory completed successfully", record)
}

func (h *WarehouseHandler) CreateMonthlyItem(c *gin.Context) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return
	}
	zoneID, err := uuid.Parse(c.Param("zone_id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid zone ID")
		return
	}
	var req service.MonthlyItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	item, err := h.warehouseService.CreateMonthlyItem(storeID, zoneID, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Monthly inventory item created successfully", item)
}

func (h *WarehouseHandler) UpdateMonthlyItem(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	var req service.MonthlyItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	item, err := h.warehouseService.UpdateMonthlyItem(storeID, id, req)
	if err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Monthly inventory item updated successfully", item)
}

func (h *WarehouseHandler) DeleteMonthlyItem(c *gin.Context) {
	storeID, id, ok := requireStoreIDAndParamID(c)
	if !ok {
		return
	}
	if err := h.warehouseService.DeleteMonthlyItem(storeID, id); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}
	utils.SuccessMessageResponse(c, "Monthly inventory item deleted successfully", nil)
}

func requireStoreID(c *gin.Context) (uuid.UUID, bool) {
	storeID, exists := c.Get("store_id")
	if !exists || storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return uuid.Nil, false
	}
	return storeID.(uuid.UUID), true
}

func requireStoreIDAndParamID(c *gin.Context) (uuid.UUID, uuid.UUID, bool) {
	storeID, ok := requireStoreID(c)
	if !ok {
		return uuid.Nil, uuid.Nil, false
	}
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid ID")
		return uuid.Nil, uuid.Nil, false
	}
	return storeID, id, true
}
