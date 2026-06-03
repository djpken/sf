package service

import (
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// ReportService handles report-related business logic
type ReportService struct {
	orderRepo *postgres.OrderRepository
	menuRepo  *postgres.MenuRepository
}

// NewReportService creates a new report service
func NewReportService(orderRepo *postgres.OrderRepository, menuRepo *postgres.MenuRepository) *ReportService {
	return &ReportService{
		orderRepo: orderRepo,
		menuRepo:  menuRepo,
	}
}

// === DTOs ===

// SalesReport represents a sales report
type SalesReport struct {
	StartDate    time.Time `json:"start_date"`
	EndDate      time.Time `json:"end_date"`
	TotalOrders  int64     `json:"total_orders"`
	TotalSales   float64   `json:"total_sales"`
	TotalTax     float64   `json:"total_tax"`
	AverageOrder float64   `json:"average_order"`
	ByOrderType  map[string]ReportBreakdown `json:"by_order_type"`
	ByPayment    map[string]ReportBreakdown `json:"by_payment"`
}

// ReportBreakdown represents a breakdown in a report
type ReportBreakdown struct {
	Count  int64   `json:"count"`
	Amount float64 `json:"amount"`
}

// ProductSalesReport represents product sales ranking
type ProductSalesReport struct {
	ItemID      uuid.UUID `json:"item_id"`
	ItemName    string    `json:"item_name"`
	CategoryID  uuid.UUID `json:"category_id"`
	Category    string    `json:"category"`
	Quantity    int       `json:"quantity"`
	TotalAmount float64   `json:"total_amount"`
	OrderCount  int       `json:"order_count"`
}

// HourlySalesReport represents hourly sales breakdown
type HourlySalesReport struct {
	Hour        int     `json:"hour"`
	OrderCount  int     `json:"order_count"`
	TotalAmount float64 `json:"total_amount"`
}

// === Report Methods ===

// GetDailySalesReport gets daily sales report
func (s *ReportService) GetDailySalesReport(storeID uuid.UUID, date time.Time) (*SalesReport, error) {
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	return s.getSalesReport(storeID, startOfDay, endOfDay)
}

// GetWeeklySalesReport gets weekly sales report
func (s *ReportService) GetWeeklySalesReport(storeID uuid.UUID, startDate time.Time) (*SalesReport, error) {
	// Start from Monday
	weekday := int(startDate.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	monday := startDate.AddDate(0, 0, -(weekday - 1))
	startOfWeek := time.Date(monday.Year(), monday.Month(), monday.Day(), 0, 0, 0, 0, monday.Location())
	endOfWeek := startOfWeek.AddDate(0, 0, 7)

	return s.getSalesReport(storeID, startOfWeek, endOfWeek)
}

// GetMonthlySalesReport gets monthly sales report
func (s *ReportService) GetMonthlySalesReport(storeID uuid.UUID, year int, month int) (*SalesReport, error) {
	startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	return s.getSalesReport(storeID, startOfMonth, endOfMonth)
}

// GetCustomSalesReport gets custom date range sales report
func (s *ReportService) GetCustomSalesReport(storeID uuid.UUID, startDate, endDate time.Time) (*SalesReport, error) {
	return s.getSalesReport(storeID, startDate, endDate)
}

// getSalesReport is a helper function to get sales report for a date range
func (s *ReportService) getSalesReport(storeID uuid.UUID, startDate, endDate time.Time) (*SalesReport, error) {
	// Get all completed orders in date range
	status := domain.OrderStatusCompleted
	orders, _, err := s.orderRepo.List(storeID, &status, nil, &startDate, &endDate, 100000, 0)
	if err != nil {
		return nil, err
	}

	// Calculate totals
	var totalSales, totalTax float64
	byOrderType := make(map[string]ReportBreakdown)
	byPayment := make(map[string]ReportBreakdown)

	for _, order := range orders {
		totalSales += order.Total
		totalTax += order.Tax

		// By order type
		orderType := string(order.OrderType)
		breakdown := byOrderType[orderType]
		breakdown.Count++
		breakdown.Amount += order.Total
		byOrderType[orderType] = breakdown

		// By payment method
		for _, payment := range order.Payments {
			method := string(payment.Method)
			payBreakdown := byPayment[method]
			payBreakdown.Count++
			payBreakdown.Amount += payment.Amount
			byPayment[method] = payBreakdown
		}
	}

	totalOrders := int64(len(orders))
	averageOrder := 0.0
	if totalOrders > 0 {
		averageOrder = totalSales / float64(totalOrders)
	}

	return &SalesReport{
		StartDate:    startDate,
		EndDate:      endDate,
		TotalOrders:  totalOrders,
		TotalSales:   totalSales,
		TotalTax:     totalTax,
		AverageOrder: averageOrder,
		ByOrderType:  byOrderType,
		ByPayment:    byPayment,
	}, nil
}

// GetProductSalesRanking gets product sales ranking
func (s *ReportService) GetProductSalesRanking(storeID uuid.UUID, startDate, endDate time.Time, limit int) ([]ProductSalesReport, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}

	// Get all completed orders in date range
	status := domain.OrderStatusCompleted
	orders, _, err := s.orderRepo.List(storeID, &status, nil, &startDate, &endDate, 100000, 0)
	if err != nil {
		return nil, err
	}

	// Aggregate product sales
	productSales := make(map[uuid.UUID]*ProductSalesReport)
	orderCountMap := make(map[uuid.UUID]map[uuid.UUID]bool) // itemID -> orderID set

	for _, order := range orders {
		for _, item := range order.Items {
			if item.ItemID == nil {
				continue
			}

			itemID := *item.ItemID

			if _, exists := productSales[itemID]; !exists {
				// Get product details
				menuItem, _ := s.menuRepo.FindItemByID(itemID)
				categoryName := ""
				categoryID := uuid.Nil
				if menuItem != nil && menuItem.Category != nil {
					categoryName = menuItem.Category.Name
					categoryID = menuItem.Category.ID
				}

				productSales[itemID] = &ProductSalesReport{
					ItemID:     itemID,
					ItemName:   item.ItemName,
					CategoryID: categoryID,
					Category:   categoryName,
				}

				orderCountMap[itemID] = make(map[uuid.UUID]bool)
			}

			productSales[itemID].Quantity += item.Quantity
			productSales[itemID].TotalAmount += item.Subtotal
			orderCountMap[itemID][order.ID] = true
		}
	}

	// Convert to slice and add order count
	var result []ProductSalesReport
	for itemID, report := range productSales {
		report.OrderCount = len(orderCountMap[itemID])
		result = append(result, *report)
	}

	// Sort by quantity (descending)
	for i := 0; i < len(result)-1; i++ {
		for j := i + 1; j < len(result); j++ {
			if result[j].Quantity > result[i].Quantity {
				result[i], result[j] = result[j], result[i]
			}
		}
	}

	// Limit results
	if len(result) > limit {
		result = result[:limit]
	}

	return result, nil
}

// GetHourlySales gets hourly sales breakdown
func (s *ReportService) GetHourlySales(storeID uuid.UUID, date time.Time) ([]HourlySalesReport, error) {
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	// Get all completed orders for the day
	status := domain.OrderStatusCompleted
	orders, _, err := s.orderRepo.List(storeID, &status, nil, &startOfDay, &endOfDay, 100000, 0)
	if err != nil {
		return nil, err
	}

	// Aggregate by hour
	hourlyData := make(map[int]*HourlySalesReport)
	for i := 0; i < 24; i++ {
		hourlyData[i] = &HourlySalesReport{Hour: i}
	}

	for _, order := range orders {
		hour := order.CreatedAt.Hour()
		hourlyData[hour].OrderCount++
		hourlyData[hour].TotalAmount += order.Total
	}

	// Convert to slice
	var result []HourlySalesReport
	for i := 0; i < 24; i++ {
		result = append(result, *hourlyData[i])
	}

	return result, nil
}

// GetCategorySales gets sales breakdown by category
func (s *ReportService) GetCategorySales(storeID uuid.UUID, startDate, endDate time.Time) (map[string]ReportBreakdown, error) {
	// Get all completed orders in date range
	status := domain.OrderStatusCompleted
	orders, _, err := s.orderRepo.List(storeID, &status, nil, &startDate, &endDate, 100000, 0)
	if err != nil {
		return nil, err
	}

	// Aggregate by category
	categorySales := make(map[string]ReportBreakdown)

	for _, order := range orders {
		for _, item := range order.Items {
			if item.ItemID == nil {
				continue
			}

			// Get product details
			menuItem, _ := s.menuRepo.FindItemByID(*item.ItemID)
			categoryName := "未分類"
			if menuItem != nil && menuItem.Category != nil {
				categoryName = menuItem.Category.Name
			}

			breakdown := categorySales[categoryName]
			breakdown.Count += int64(item.Quantity)
			breakdown.Amount += item.Subtotal
			categorySales[categoryName] = breakdown
		}
	}

	return categorySales, nil
}

// GetSalesSummary gets a quick sales summary
func (s *ReportService) GetSalesSummary(storeID uuid.UUID) (map[string]interface{}, error) {
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	// Today's sales
	todaySales, _ := s.orderRepo.GetDailySales(storeID, today)

	// Yesterday's sales
	yesterday := today.AddDate(0, 0, -1)
	yesterdaySales, _ := s.orderRepo.GetDailySales(storeID, yesterday)

	// This week
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	monday := now.AddDate(0, 0, -(weekday - 1))
	startOfWeek := time.Date(monday.Year(), monday.Month(), monday.Day(), 0, 0, 0, 0, monday.Location())
	weekReport, _ := s.getSalesReport(storeID, startOfWeek, now)

	// This month
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	monthReport, _ := s.getSalesReport(storeID, startOfMonth, now)

	return map[string]interface{}{
		"today": map[string]interface{}{
			"sales": todaySales,
			"change": todaySales - yesterdaySales,
		},
		"this_week": map[string]interface{}{
			"total_orders": weekReport.TotalOrders,
			"total_sales":  weekReport.TotalSales,
		},
		"this_month": map[string]interface{}{
			"total_orders": monthReport.TotalOrders,
			"total_sales":  monthReport.TotalSales,
		},
	}, nil
}
