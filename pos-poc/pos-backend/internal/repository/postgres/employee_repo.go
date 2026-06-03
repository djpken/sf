package postgres

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"gorm.io/gorm"
)

// EmployeeRepository handles employee data access
type EmployeeRepository struct {
	db *gorm.DB
}

// NewEmployeeRepository creates a new employee repository
func NewEmployeeRepository(db *gorm.DB) *EmployeeRepository {
	return &EmployeeRepository{db: db}
}

// FindByID finds an employee by ID
func (r *EmployeeRepository) FindByID(id uuid.UUID) (*domain.Employee, error) {
	var employee domain.Employee
	if err := r.db.Where("id = ?", id).First(&employee).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &employee, nil
}

// FindByEmail finds an employee by email
func (r *EmployeeRepository) FindByEmail(email string) (*domain.Employee, error) {
	var employee domain.Employee
	if err := r.db.Where("email = ?", email).First(&employee).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &employee, nil
}

// FindByPinCode finds an employee by PIN code
func (r *EmployeeRepository) FindByPinCode(tenantID uuid.UUID, pinCode string) (*domain.Employee, error) {
	var employee domain.Employee
	if err := r.db.Where("tenant_id = ? AND pin_code = ?", tenantID, pinCode).First(&employee).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &employee, nil
}

// Create creates a new employee
func (r *EmployeeRepository) Create(employee *domain.Employee) error {
	return r.db.Create(employee).Error
}

// Update updates an employee
func (r *EmployeeRepository) Update(employee *domain.Employee) error {
	return r.db.Save(employee).Error
}

// Delete deletes an employee (soft delete)
func (r *EmployeeRepository) Delete(id uuid.UUID) error {
	return r.db.Model(&domain.Employee{}).Where("id = ?", id).Update("is_active", false).Error
}

// List lists employees with optional filters
func (r *EmployeeRepository) List(tenantID uuid.UUID, storeID *uuid.UUID) ([]domain.Employee, error) {
	var employees []domain.Employee
	query := r.db.Where("tenant_id = ? AND is_active = ?", tenantID, true)

	if storeID != nil {
		query = query.Where("store_id = ?", *storeID)
	}

	if err := query.Find(&employees).Error; err != nil {
		return nil, err
	}
	return employees, nil
}
