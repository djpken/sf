package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// TableHandler handles table-related endpoints
type TableHandler struct {
	tableService *service.TableService
}

// NewTableHandler creates a new table handler
func NewTableHandler(tableService *service.TableService) *TableHandler {
	return &TableHandler{
		tableService: tableService,
	}
}

// ListTables lists all tables in a store
// @Summary List tables
// @Tags tables
// @Produce json
// @Param area query string false "Filter by area"
// @Param status query string false "Filter by status"
// @Success 200 {array} domain.Table
// @Security BearerAuth
// @Router /tables [get]
func (h *TableHandler) ListTables(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	var area *string
	if a := c.Query("area"); a != "" {
		area = &a
	}

	var status *domain.TableStatus
	if s := c.Query("status"); s != "" {
		st := domain.TableStatus(s)
		status = &st
	}

	tables, err := h.tableService.ListTables(storeID.(uuid.UUID), area, status)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, tables)
}

// GetTable gets a table by ID
// @Summary Get table by ID
// @Tags tables
// @Produce json
// @Param id path string true "Table ID"
// @Success 200 {object} domain.Table
// @Security BearerAuth
// @Router /tables/{id} [get]
func (h *TableHandler) GetTable(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid table ID")
		return
	}

	table, err := h.tableService.GetTable(id)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, table)
}

// GetTableWithOrders gets a table with its current orders
// @Summary Get table with orders
// @Tags tables
// @Produce json
// @Param id path string true "Table ID"
// @Success 200 {object} service.TableWithOrders
// @Security BearerAuth
// @Router /tables/{id}/orders [get]
func (h *TableHandler) GetTableWithOrders(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid table ID")
		return
	}

	table, err := h.tableService.GetTableWithOrders(id)
	if err != nil {
		utils.NotFoundResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, table)
}

// CreateTable creates a new table
// @Summary Create table
// @Tags tables
// @Accept json
// @Produce json
// @Param request body service.CreateTableRequest true "Table data"
// @Success 200 {object} domain.Table
// @Security BearerAuth
// @Router /tables [post]
func (h *TableHandler) CreateTable(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	var req service.CreateTableRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	table, err := h.tableService.CreateTable(storeID.(uuid.UUID), req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Table created successfully", table)
}

// UpdateTable updates a table
// @Summary Update table
// @Tags tables
// @Accept json
// @Produce json
// @Param id path string true "Table ID"
// @Param request body service.UpdateTableRequest true "Table data"
// @Success 200 {object} domain.Table
// @Security BearerAuth
// @Router /tables/{id} [put]
func (h *TableHandler) UpdateTable(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid table ID")
		return
	}

	var req service.UpdateTableRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	table, err := h.tableService.UpdateTable(id, req)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Table updated successfully", table)
}

// UpdateTableStatus updates table status
// @Summary Update table status
// @Tags tables
// @Accept json
// @Produce json
// @Param id path string true "Table ID"
// @Param request body object{status=string} true "Status"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /tables/{id}/status [put]
func (h *TableHandler) UpdateTableStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid table ID")
		return
	}

	var req struct {
		Status domain.TableStatus `json:"status" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	if err := h.tableService.UpdateTableStatus(id, req.Status); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Table status updated successfully", nil)
}

// DeleteTable deletes a table
// @Summary Delete table
// @Tags tables
// @Produce json
// @Param id path string true "Table ID"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /tables/{id} [delete]
func (h *TableHandler) DeleteTable(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		utils.BadRequestResponse(c, "Invalid table ID")
		return
	}

	if err := h.tableService.DeleteTable(id); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Table deleted successfully", nil)
}

// GetAvailableTables gets all available tables
// @Summary Get available tables
// @Tags tables
// @Produce json
// @Param area query string false "Filter by area"
// @Success 200 {array} domain.Table
// @Security BearerAuth
// @Router /tables/available [get]
func (h *TableHandler) GetAvailableTables(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	var area *string
	if a := c.Query("area"); a != "" {
		area = &a
	}

	tables, err := h.tableService.GetAvailableTables(storeID.(uuid.UUID), area)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, tables)
}

// GetOccupiedTables gets all occupied tables with their orders
// @Summary Get occupied tables with orders
// @Tags tables
// @Produce json
// @Success 200 {array} service.TableWithOrders
// @Security BearerAuth
// @Router /tables/occupied [get]
func (h *TableHandler) GetOccupiedTables(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	tables, err := h.tableService.GetOccupiedTablesWithOrders(storeID.(uuid.UUID))
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, tables)
}

// GetTableStats gets table statistics
// @Summary Get table statistics
// @Tags tables
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Security BearerAuth
// @Router /tables/stats [get]
func (h *TableHandler) GetTableStats(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	stats, err := h.tableService.GetTableStats(storeID.(uuid.UUID))
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, stats)
}

// GetAreaList gets all areas in a store
// @Summary Get area list
// @Tags tables
// @Produce json
// @Success 200 {array} string
// @Security BearerAuth
// @Router /tables/areas [get]
func (h *TableHandler) GetAreaList(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	areas, err := h.tableService.GetAreaList(storeID.(uuid.UUID))
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, areas)
}

// TransferTable transfers an order from one table to another
// @Summary Transfer table
// @Tags tables
// @Accept json
// @Produce json
// @Param request body object{order_id=string,from_table_id=string,to_table_id=string} true "Transfer data"
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /tables/transfer [post]
func (h *TableHandler) TransferTable(c *gin.Context) {
	var req struct {
		OrderID     uuid.UUID `json:"order_id" binding:"required"`
		FromTableID uuid.UUID `json:"from_table_id" binding:"required"`
		ToTableID   uuid.UUID `json:"to_table_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	if err := h.tableService.TransferTable(req.OrderID, req.FromTableID, req.ToTableID); err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessMessageResponse(c, "Table transferred successfully", nil)
}
