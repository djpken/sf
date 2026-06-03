package service

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

// TableService handles table-related business logic
type TableService struct {
	tableRepo *postgres.TableRepository
	orderRepo *postgres.OrderRepository
}

// NewTableService creates a new table service
func NewTableService(tableRepo *postgres.TableRepository, orderRepo *postgres.OrderRepository) *TableService {
	return &TableService{
		tableRepo: tableRepo,
		orderRepo: orderRepo,
	}
}

// === DTOs ===

// CreateTableRequest represents a request to create a table
type CreateTableRequest struct {
	Name     string `json:"name" binding:"required,min=1,max=20"`
	Capacity int    `json:"capacity" binding:"required,gt=0"`
	Area     string `json:"area,omitempty"`
}

// UpdateTableRequest represents a request to update a table
type UpdateTableRequest struct {
	Name     *string             `json:"name,omitempty"`
	Capacity *int                `json:"capacity,omitempty"`
	Area     *string             `json:"area,omitempty"`
	Status   *domain.TableStatus `json:"status,omitempty"`
}

// TableWithOrders represents a table with its current orders
type TableWithOrders struct {
	domain.Table
	CurrentOrders []domain.Order `json:"current_orders,omitempty"`
}

// === Table Methods ===

// ListTables lists all tables in a store
func (s *TableService) ListTables(storeID uuid.UUID, area *string, status *domain.TableStatus) ([]domain.Table, error) {
	return s.tableRepo.List(storeID, area, status)
}

// GetTable gets a table by ID
func (s *TableService) GetTable(id uuid.UUID) (*domain.Table, error) {
	table, err := s.tableRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if table == nil {
		return nil, errors.New("table not found")
	}
	return table, nil
}

// GetTableWithOrders gets a table with its current orders
func (s *TableService) GetTableWithOrders(id uuid.UUID) (*TableWithOrders, error) {
	table, err := s.tableRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if table == nil {
		return nil, errors.New("table not found")
	}

	// Get current orders for this table
	orders, err := s.orderRepo.ListByTable(id)
	if err != nil {
		return nil, err
	}

	return &TableWithOrders{
		Table:         *table,
		CurrentOrders: orders,
	}, nil
}

// CreateTable creates a new table
func (s *TableService) CreateTable(storeID uuid.UUID, req CreateTableRequest) (*domain.Table, error) {
	// Check if table name already exists in this store
	existing, err := s.tableRepo.FindByName(storeID, req.Name)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, errors.New("table name already exists in this store")
	}

	table := &domain.Table{
		StoreID:  storeID,
		Name:     req.Name,
		Capacity: req.Capacity,
		Area:     req.Area,
		Status:   domain.TableStatusAvailable,
	}

	if err := s.tableRepo.Create(table); err != nil {
		return nil, err
	}

	return table, nil
}

// UpdateTable updates a table
func (s *TableService) UpdateTable(id uuid.UUID, req UpdateTableRequest) (*domain.Table, error) {
	table, err := s.tableRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	if table == nil {
		return nil, errors.New("table not found")
	}

	// Update fields if provided
	if req.Name != nil {
		// Check if new name conflicts with existing table
		existing, err := s.tableRepo.FindByName(table.StoreID, *req.Name)
		if err != nil {
			return nil, err
		}
		if existing != nil && existing.ID != id {
			return nil, errors.New("table name already exists in this store")
		}
		table.Name = *req.Name
	}
	if req.Capacity != nil {
		table.Capacity = *req.Capacity
	}
	if req.Area != nil {
		table.Area = *req.Area
	}
	if req.Status != nil {
		table.Status = *req.Status
	}

	if err := s.tableRepo.Update(table); err != nil {
		return nil, err
	}

	return table, nil
}

// UpdateTableStatus updates table status
func (s *TableService) UpdateTableStatus(id uuid.UUID, status domain.TableStatus) error {
	table, err := s.tableRepo.FindByID(id)
	if err != nil {
		return err
	}
	if table == nil {
		return errors.New("table not found")
	}

	// Validate status transition
	if status == domain.TableStatusOccupied && table.Status == domain.TableStatusOccupied {
		return errors.New("table is already occupied")
	}
	if status == domain.TableStatusAvailable {
		// Check if table has active orders
		orders, err := s.orderRepo.ListByTable(id)
		if err != nil {
			return err
		}
		if len(orders) > 0 {
			return errors.New("cannot mark table as available while it has active orders")
		}
	}

	return s.tableRepo.UpdateStatus(id, status)
}

// DeleteTable deletes a table
func (s *TableService) DeleteTable(id uuid.UUID) error {
	table, err := s.tableRepo.FindByID(id)
	if err != nil {
		return err
	}
	if table == nil {
		return errors.New("table not found")
	}

	// Check if table is occupied
	if table.Status == domain.TableStatusOccupied {
		return errors.New("cannot delete occupied table")
	}

	// Check if table has any orders
	orders, err := s.orderRepo.ListByTable(id)
	if err != nil {
		return err
	}
	if len(orders) > 0 {
		return errors.New("cannot delete table with existing orders")
	}

	return s.tableRepo.Delete(id)
}

// GetAvailableTables gets all available tables
func (s *TableService) GetAvailableTables(storeID uuid.UUID, area *string) ([]domain.Table, error) {
	return s.tableRepo.GetAvailableTables(storeID, area)
}

// GetOccupiedTablesWithOrders gets all occupied tables with their orders
func (s *TableService) GetOccupiedTablesWithOrders(storeID uuid.UUID) ([]TableWithOrders, error) {
	tables, err := s.tableRepo.GetOccupiedTables(storeID)
	if err != nil {
		return nil, err
	}

	var result []TableWithOrders
	for _, table := range tables {
		orders, err := s.orderRepo.ListByTable(table.ID)
		if err != nil {
			return nil, err
		}

		result = append(result, TableWithOrders{
			Table:         table,
			CurrentOrders: orders,
		})
	}

	return result, nil
}

// GetTableStats gets table statistics
func (s *TableService) GetTableStats(storeID uuid.UUID) (map[string]interface{}, error) {
	stats, err := s.tableRepo.GetTableStats(storeID)
	if err != nil {
		return nil, err
	}

	// Calculate totals
	total := 0
	for _, count := range stats {
		total += count
	}

	result := map[string]interface{}{
		"total":     total,
		"available": stats[string(domain.TableStatusAvailable)],
		"occupied":  stats[string(domain.TableStatusOccupied)],
		"reserved":  stats[string(domain.TableStatusReserved)],
		"by_status": stats,
	}

	return result, nil
}

// GetAreaList gets all areas in a store
func (s *TableService) GetAreaList(storeID uuid.UUID) ([]string, error) {
	return s.tableRepo.GetAreaList(storeID)
}

// TransferTable transfers an order from one table to another
func (s *TableService) TransferTable(orderID, fromTableID, toTableID uuid.UUID) error {
	// Validate from table
	fromTable, err := s.tableRepo.FindByID(fromTableID)
	if err != nil {
		return err
	}
	if fromTable == nil {
		return errors.New("source table not found")
	}

	// Validate to table
	toTable, err := s.tableRepo.FindByID(toTableID)
	if err != nil {
		return err
	}
	if toTable == nil {
		return errors.New("destination table not found")
	}

	if toTable.Status == domain.TableStatusOccupied {
		return errors.New("destination table is already occupied")
	}

	// Get and update order
	order, err := s.orderRepo.FindByID(orderID)
	if err != nil {
		return err
	}
	if order == nil {
		return errors.New("order not found")
	}

	if order.TableID == nil || *order.TableID != fromTableID {
		return errors.New("order does not belong to source table")
	}

	// Update order table
	order.TableID = &toTableID
	if err := s.orderRepo.Update(order); err != nil {
		return err
	}

	// Update table statuses
	// Check if from table still has orders
	fromOrders, err := s.orderRepo.ListByTable(fromTableID)
	if err != nil {
		return err
	}
	if len(fromOrders) == 0 {
		if err := s.tableRepo.UpdateStatus(fromTableID, domain.TableStatusAvailable); err != nil {
			return err
		}
	}

	// Mark destination table as occupied
	if err := s.tableRepo.UpdateStatus(toTableID, domain.TableStatusOccupied); err != nil {
		return err
	}

	return nil
}
