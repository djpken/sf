package handler

import (
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// ReportHandler handles report-related endpoints
type ReportHandler struct {
	reportService *service.ReportService
}

// NewReportHandler creates a new report handler
func NewReportHandler(reportService *service.ReportService) *ReportHandler {
	return &ReportHandler{
		reportService: reportService,
	}
}

// GetDailySalesReport gets daily sales report
// @Summary Get daily sales report
// @Tags reports
// @Produce json
// @Param date query string false "Date (YYYY-MM-DD)" default(today)
// @Success 200 {object} service.SalesReport
// @Security BearerAuth
// @Router /reports/sales/daily [get]
func (h *ReportHandler) GetDailySalesReport(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	dateStr := c.DefaultQuery("date", time.Now().Format("2006-01-02"))
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid date format (use YYYY-MM-DD)")
		return
	}

	report, err := h.reportService.GetDailySalesReport(storeID.(uuid.UUID), date)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetWeeklySalesReport gets weekly sales report
// @Summary Get weekly sales report
// @Tags reports
// @Produce json
// @Param start_date query string false "Week start date (YYYY-MM-DD)" default(this_week)
// @Success 200 {object} service.SalesReport
// @Security BearerAuth
// @Router /reports/sales/weekly [get]
func (h *ReportHandler) GetWeeklySalesReport(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	monday := now.AddDate(0, 0, -(weekday - 1))

	dateStr := c.DefaultQuery("start_date", monday.Format("2006-01-02"))
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid date format (use YYYY-MM-DD)")
		return
	}

	report, err := h.reportService.GetWeeklySalesReport(storeID.(uuid.UUID), date)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetMonthlySalesReport gets monthly sales report
// @Summary Get monthly sales report
// @Tags reports
// @Produce json
// @Param year query int false "Year" default(current_year)
// @Param month query int false "Month (1-12)" default(current_month)
// @Success 200 {object} service.SalesReport
// @Security BearerAuth
// @Router /reports/sales/monthly [get]
func (h *ReportHandler) GetMonthlySalesReport(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	now := time.Now()
	year, _ := strconv.Atoi(c.DefaultQuery("year", strconv.Itoa(now.Year())))
	month, _ := strconv.Atoi(c.DefaultQuery("month", strconv.Itoa(int(now.Month()))))

	if month < 1 || month > 12 {
		utils.BadRequestResponse(c, "Month must be between 1 and 12")
		return
	}

	report, err := h.reportService.GetMonthlySalesReport(storeID.(uuid.UUID), year, month)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetCustomSalesReport gets custom date range sales report
// @Summary Get custom sales report
// @Tags reports
// @Produce json
// @Param start_date query string true "Start date (YYYY-MM-DD)"
// @Param end_date query string true "End date (YYYY-MM-DD)"
// @Success 200 {object} service.SalesReport
// @Security BearerAuth
// @Router /reports/sales/custom [get]
func (h *ReportHandler) GetCustomSalesReport(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr == "" || endDateStr == "" {
		utils.BadRequestResponse(c, "start_date and end_date are required")
		return
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid start_date format (use YYYY-MM-DD)")
		return
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid end_date format (use YYYY-MM-DD)")
		return
	}

	// Add 1 day to end date to include the whole day
	endDate = endDate.Add(24 * time.Hour)

	report, err := h.reportService.GetCustomSalesReport(storeID.(uuid.UUID), startDate, endDate)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetProductSalesRanking gets product sales ranking
// @Summary Get product sales ranking
// @Tags reports
// @Produce json
// @Param start_date query string true "Start date (YYYY-MM-DD)"
// @Param end_date query string true "End date (YYYY-MM-DD)"
// @Param limit query int false "Limit" default(20)
// @Success 200 {array} service.ProductSalesReport
// @Security BearerAuth
// @Router /reports/products/ranking [get]
func (h *ReportHandler) GetProductSalesRanking(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr == "" || endDateStr == "" {
		utils.BadRequestResponse(c, "start_date and end_date are required")
		return
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid start_date format (use YYYY-MM-DD)")
		return
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid end_date format (use YYYY-MM-DD)")
		return
	}

	// Add 1 day to end date to include the whole day
	endDate = endDate.Add(24 * time.Hour)

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	ranking, err := h.reportService.GetProductSalesRanking(storeID.(uuid.UUID), startDate, endDate, limit)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, ranking)
}

// GetHourlySales gets hourly sales breakdown
// @Summary Get hourly sales
// @Tags reports
// @Produce json
// @Param date query string false "Date (YYYY-MM-DD)" default(today)
// @Success 200 {array} service.HourlySalesReport
// @Security BearerAuth
// @Router /reports/sales/hourly [get]
func (h *ReportHandler) GetHourlySales(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	dateStr := c.DefaultQuery("date", time.Now().Format("2006-01-02"))
	date, err := time.Parse("2006-01-02", dateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid date format (use YYYY-MM-DD)")
		return
	}

	report, err := h.reportService.GetHourlySales(storeID.(uuid.UUID), date)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetCategorySales gets sales breakdown by category
// @Summary Get category sales
// @Tags reports
// @Produce json
// @Param start_date query string true "Start date (YYYY-MM-DD)"
// @Param end_date query string true "End date (YYYY-MM-DD)"
// @Success 200 {object} map[string]service.ReportBreakdown
// @Security BearerAuth
// @Router /reports/categories/sales [get]
func (h *ReportHandler) GetCategorySales(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	if startDateStr == "" || endDateStr == "" {
		utils.BadRequestResponse(c, "start_date and end_date are required")
		return
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid start_date format (use YYYY-MM-DD)")
		return
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		utils.BadRequestResponse(c, "Invalid end_date format (use YYYY-MM-DD)")
		return
	}

	// Add 1 day to end date to include the whole day
	endDate = endDate.Add(24 * time.Hour)

	report, err := h.reportService.GetCategorySales(storeID.(uuid.UUID), startDate, endDate)
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, report)
}

// GetSalesSummary gets a quick sales summary
// @Summary Get sales summary
// @Tags reports
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Security BearerAuth
// @Router /reports/summary [get]
func (h *ReportHandler) GetSalesSummary(c *gin.Context) {
	storeID, _ := c.Get("store_id")
	if storeID == nil {
		utils.BadRequestResponse(c, "store_id is required in token")
		return
	}

	summary, err := h.reportService.GetSalesSummary(storeID.(uuid.UUID))
	if err != nil {
		utils.InternalServerErrorResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, summary)
}
