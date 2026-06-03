package handler

import (
	"github.com/gin-gonic/gin"
	"github.com/yourusername/pos-backend/internal/service"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// AuthHandler handles authentication endpoints
type AuthHandler struct {
	authService *service.AuthService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

// Login handles email/password login
// @Summary Login with email and password
// @Tags auth
// @Accept json
// @Produce json
// @Param request body service.LoginRequest true "Login credentials"
// @Success 200 {object} service.LoginResponse
// @Router /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req service.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	resp, err := h.authService.Login(req)
	if err != nil {
		utils.UnauthorizedResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, resp)
}

// PinLogin handles PIN code login
// @Summary Login with PIN code
// @Tags auth
// @Accept json
// @Produce json
// @Param request body service.PinLoginRequest true "PIN login credentials"
// @Success 200 {object} service.LoginResponse
// @Router /auth/pin-login [post]
func (h *AuthHandler) PinLogin(c *gin.Context) {
	var req service.PinLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.BadRequestResponse(c, err.Error())
		return
	}

	resp, err := h.authService.PinLogin(req)
	if err != nil {
		utils.UnauthorizedResponse(c, err.Error())
		return
	}

	utils.SuccessResponse(c, resp)
}

// Logout handles logout
// @Summary Logout
// @Tags auth
// @Success 200 {object} utils.Response
// @Security BearerAuth
// @Router /auth/logout [post]
func (h *AuthHandler) Logout(c *gin.Context) {
	// In a stateless JWT system, logout is typically handled client-side
	// by removing the token. For server-side logout, implement token blacklist with Redis
	utils.SuccessMessageResponse(c, "Logged out successfully", nil)
}
