package postgres

import (
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

// OrderRepository handles order-related data access
type OrderRepository struct {
	db *gorm.DB
}

// NewOrderRepository creates a new order repository
func NewOrderRepository(db *gorm.DB) *OrderRepository {
	return &OrderRepository{db: db}
}

// GenerateOrderNo generates a unique order number for today
func (r *OrderRepository) GenerateOrderNo(storeID uuid.UUID) (string, error) {
	var count int64
	today := time.Now().Format("20060102")

	// Count today's orders for this store
	if err := r.db.Model(&domain.Order{}).
		Where("store_id = ? AND DATE(created_at) = CURRENT_DATE", storeID).
		Count(&count).Error; err != nil {
		return "", err
	}

	// Format: YYYYMMDD-0001
	orderNo := fmt.Sprintf("%s-%04d", today, count+1)
	return orderNo, nil
}

// FindByID finds an order by ID
func (r *OrderRepository) FindByID(id uuid.UUID) (*domain.Order, error) {
	var order domain.Order
	if err := r.db.
		Preload("Items").
		Preload("Items.Item").
		Preload("Payments").
		Preload("Invoice").
		Preload("Table").
		Preload("Employee").
		Where("id = ?", id).
		First(&order).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &order, nil
}

// FindByOrderNo finds an order by order number
func (r *OrderRepository) FindByOrderNo(storeID uuid.UUID, orderNo string) (*domain.Order, error) {
	var order domain.Order
	if err := r.db.
		Preload("Items").
		Preload("Payments").
		Where("store_id = ? AND order_no = ?", storeID, orderNo).
		First(&order).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &order, nil
}

// List lists orders with filters
func (r *OrderRepository) List(storeID uuid.UUID, status *domain.OrderStatus, paymentStatus *domain.PaymentStatus, startDate, endDate *time.Time, limit, offset int) ([]domain.Order, int64, error) {
	var orders []domain.Order
	var total int64

	query := r.db.Model(&domain.Order{}).Where("store_id = ?", storeID)

	if status != nil {
		query = query.Where("status = ?", *status)
	}
	if paymentStatus != nil {
		query = query.Where("payment_status = ?", *paymentStatus)
	}
	if startDate != nil {
		query = query.Where("created_at >= ?", *startDate)
	}
	if endDate != nil {
		query = query.Where("created_at <= ?", *endDate)
	}

	// Get total count
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get paginated results
	if err := query.
		Preload("Items").
		Preload("Payments").
		Preload("Table").
		Preload("Employee").
		Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&orders).Error; err != nil {
		return nil, 0, err
	}

	return orders, total, nil
}

// ListByTable lists orders for a specific table
func (r *OrderRepository) ListByTable(tableID uuid.UUID) ([]domain.Order, error) {
	var orders []domain.Order
	if err := r.db.
		Preload("Items").
		Preload("Payments").
		Where("table_id = ? AND status NOT IN ?", tableID, []string{"completed", "cancelled"}).
		Order("created_at DESC").
		Find(&orders).Error; err != nil {
		return nil, err
	}
	return orders, nil
}

// Create creates a new order
func (r *OrderRepository) Create(order *domain.Order) error {
	return r.db.Create(order).Error
}

// Update updates an order
func (r *OrderRepository) Update(order *domain.Order) error {
	return r.db.Save(order).Error
}

// UpdateStatus updates order status
func (r *OrderRepository) UpdateStatus(id uuid.UUID, status domain.OrderStatus) error {
	return r.db.Model(&domain.Order{}).Where("id = ?", id).Update("status", status).Error
}

// UpdatePaymentStatus updates payment status
func (r *OrderRepository) UpdatePaymentStatus(id uuid.UUID, status domain.PaymentStatus) error {
	return r.db.Model(&domain.Order{}).Where("id = ?", id).Update("payment_status", status).Error
}

// Delete deletes an order (hard delete for cancelled orders)
func (r *OrderRepository) Delete(id uuid.UUID) error {
	return r.db.Delete(&domain.Order{}, id).Error
}

// === Order Items ===

// AddItem adds an item to an order
func (r *OrderRepository) AddItem(item *domain.OrderItem) error {
	return r.db.Create(item).Error
}

// UpdateItem updates an order item
func (r *OrderRepository) UpdateItem(item *domain.OrderItem) error {
	return r.db.Save(item).Error
}

// RemoveItem removes an item from an order
func (r *OrderRepository) RemoveItem(id uuid.UUID) error {
	return r.db.Delete(&domain.OrderItem{}, id).Error
}

// UpdateItemStatus updates order item status
func (r *OrderRepository) UpdateItemStatus(id uuid.UUID, status domain.OrderItemStatus) error {
	return r.db.Model(&domain.OrderItem{}).Where("id = ?", id).Update("status", status).Error
}

// === Payments ===

// AddPayment adds a payment to an order
func (r *OrderRepository) AddPayment(payment *domain.Payment) error {
	return r.db.Create(payment).Error
}

// GetPaymentsByOrder gets all payments for an order
func (r *OrderRepository) GetPaymentsByOrder(orderID uuid.UUID) ([]domain.Payment, error) {
	var payments []domain.Payment
	if err := r.db.Where("order_id = ?", orderID).Find(&payments).Error; err != nil {
		return nil, err
	}
	return payments, nil
}

// === Invoice Methods ===

// CreateInvoice creates a new invoice record.
func (r *OrderRepository) CreateInvoice(invoice *domain.Invoice) error {
	return r.db.Create(invoice).Error
}

// UpdateInvoice updates an existing invoice record.
func (r *OrderRepository) UpdateInvoice(invoice *domain.Invoice) error {
	return r.db.Save(invoice).Error
}

// FindInvoiceByNo finds an invoice by its invoice number.
func (r *OrderRepository) FindInvoiceByNo(invoiceNo string) (*domain.Invoice, error) {
	var invoice domain.Invoice
	if err := r.db.Where("invoice_no = ?", invoiceNo).First(&invoice).Error; err != nil {
		return nil, err
	}
	return &invoice, nil
}

// === Statistics ===

// GetDailySales gets total sales for a store on a specific date
func (r *OrderRepository) GetDailySales(storeID uuid.UUID, date time.Time) (float64, error) {
	var total float64
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.Add(24 * time.Hour)

	if err := r.db.Model(&domain.Order{}).
		Where("store_id = ? AND status = ? AND created_at >= ? AND created_at < ?",
			storeID, domain.OrderStatusCompleted, startOfDay, endOfDay).
		Select("COALESCE(SUM(total), 0)").
		Scan(&total).Error; err != nil {
		return 0, err
	}

	return total, nil
}

// GetOrderCount gets order count for a store within a date range
func (r *OrderRepository) GetOrderCount(storeID uuid.UUID, startDate, endDate time.Time) (int64, error) {
	var count int64
	if err := r.db.Model(&domain.Order{}).
		Where("store_id = ? AND created_at >= ? AND created_at < ?",
			storeID, startDate, endDate).
		Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}
