package service

import (
	"errors"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// AuthService handles authentication logic
type AuthService struct {
	employeeRepo *postgres.EmployeeRepository
	jwtSecret    string
	jwtExpireHour int
}

// NewAuthService creates a new auth service
func NewAuthService(employeeRepo *postgres.EmployeeRepository, jwtSecret string, jwtExpireHour int) *AuthService {
	return &AuthService{
		employeeRepo:  employeeRepo,
		jwtSecret:     jwtSecret,
		jwtExpireHour: jwtExpireHour,
	}
}

// LoginRequest represents a login request
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// PinLoginRequest represents a PIN login request
type PinLoginRequest struct {
	TenantID uuid.UUID `json:"tenant_id" binding:"required"`
	PinCode  string    `json:"pin_code" binding:"required"`
}

// LoginResponse represents a login response
type LoginResponse struct {
	Token    string           `json:"token"`
	Employee *domain.Employee `json:"employee"`
}

// Login authenticates a user with email and password
func (s *AuthService) Login(req LoginRequest) (*LoginResponse, error) {
	employee, err := s.employeeRepo.FindByEmail(req.Email)
	if err != nil {
		return nil, err
	}

	if employee == nil {
		return nil, errors.New("invalid credentials")
	}

	if !employee.IsActive {
		return nil, errors.New("account is inactive")
	}

	if !utils.CheckPassword(employee.PasswordHash, req.Password) {
		return nil, errors.New("invalid credentials")
	}

	token, err := utils.GenerateToken(
		employee.ID,
		employee.TenantID,
		employee.StoreID,
		string(employee.Role),
		s.jwtSecret,
		s.jwtExpireHour,
	)
	if err != nil {
		return nil, err
	}

	// Clear password hash from response
	employee.PasswordHash = ""

	return &LoginResponse{
		Token:    token,
		Employee: employee,
	}, nil
}

// PinLogin authenticates a user with PIN code
func (s *AuthService) PinLogin(req PinLoginRequest) (*LoginResponse, error) {
	employee, err := s.employeeRepo.FindByPinCode(req.TenantID, req.PinCode)
	if err != nil {
		return nil, err
	}

	if employee == nil {
		return nil, errors.New("invalid PIN code")
	}

	if !employee.IsActive {
		return nil, errors.New("account is inactive")
	}

	token, err := utils.GenerateToken(
		employee.ID,
		employee.TenantID,
		employee.StoreID,
		string(employee.Role),
		s.jwtSecret,
		s.jwtExpireHour,
	)
	if err != nil {
		return nil, err
	}

	// Clear password hash from response
	employee.PasswordHash = ""

	return &LoginResponse{
		Token:    token,
		Employee: employee,
	}, nil
}
