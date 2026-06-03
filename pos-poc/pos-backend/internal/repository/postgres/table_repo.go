package postgres

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

// TableRepository handles table-related data access
type TableRepository struct {
	db *gorm.DB
}

// NewTableRepository creates a new table repository
func NewTableRepository(db *gorm.DB) *TableRepository {
	return &TableRepository{db: db}
}

// FindByID finds a table by ID
func (r *TableRepository) FindByID(id uuid.UUID) (*domain.Table, error) {
	var table domain.Table
	if err := r.db.Where("id = ?", id).First(&table).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &table, nil
}

// FindByName finds a table by name in a store
func (r *TableRepository) FindByName(storeID uuid.UUID, name string) (*domain.Table, error) {
	var table domain.Table
	if err := r.db.Where("store_id = ? AND name = ?", storeID, name).First(&table).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &table, nil
}

// List lists all tables in a store
func (r *TableRepository) List(storeID uuid.UUID, area *string, status *domain.TableStatus) ([]domain.Table, error) {
	var tables []domain.Table
	query := r.db.Where("store_id = ?", storeID)

	if area != nil {
		query = query.Where("area = ?", *area)
	}
	if status != nil {
		query = query.Where("status = ?", *status)
	}

	if err := query.Order("area ASC, name ASC").Find(&tables).Error; err != nil {
		return nil, err
	}
	return tables, nil
}

// Create creates a new table
func (r *TableRepository) Create(table *domain.Table) error {
	return r.db.Create(table).Error
}

// Update updates a table
func (r *TableRepository) Update(table *domain.Table) error {
	return r.db.Save(table).Error
}

// UpdateStatus updates table status
func (r *TableRepository) UpdateStatus(id uuid.UUID, status domain.TableStatus) error {
	return r.db.Model(&domain.Table{}).Where("id = ?", id).Update("status", status).Error
}

// Delete deletes a table
func (r *TableRepository) Delete(id uuid.UUID) error {
	return r.db.Delete(&domain.Table{}, id).Error
}

// GetAvailableTables gets all available tables in a store
func (r *TableRepository) GetAvailableTables(storeID uuid.UUID, area *string) ([]domain.Table, error) {
	status := domain.TableStatusAvailable
	return r.List(storeID, area, &status)
}

// GetOccupiedTables gets all occupied tables with their current orders
func (r *TableRepository) GetOccupiedTables(storeID uuid.UUID) ([]domain.Table, error) {
	var tables []domain.Table
	if err := r.db.Where("store_id = ? AND status = ?", storeID, domain.TableStatusOccupied).
		Order("area ASC, name ASC").
		Find(&tables).Error; err != nil {
		return nil, err
	}
	return tables, nil
}

// GetTableStats gets statistics for tables in a store
func (r *TableRepository) GetTableStats(storeID uuid.UUID) (map[string]int, error) {
	type Result struct {
		Status string
		Count  int
	}

	var results []Result
	if err := r.db.Model(&domain.Table{}).
		Select("status, COUNT(*) as count").
		Where("store_id = ?", storeID).
		Group("status").
		Scan(&results).Error; err != nil {
		return nil, err
	}

	stats := make(map[string]int)
	for _, r := range results {
		stats[r.Status] = r.Count
	}

	return stats, nil
}

// GetAreaList gets all unique areas in a store
func (r *TableRepository) GetAreaList(storeID uuid.UUID) ([]string, error) {
	var areas []string
	if err := r.db.Model(&domain.Table{}).
		Where("store_id = ?", storeID).
		Distinct("area").
		Order("area ASC").
		Pluck("area", &areas).Error; err != nil {
		return nil, err
	}
	return areas, nil
}
