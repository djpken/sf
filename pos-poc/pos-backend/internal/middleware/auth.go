package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/yourusername/pos-backend/pkg/utils"
)

// AuthMiddleware validates JWT token
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			utils.UnauthorizedResponse(c, "Authorization header required")
			c.Abort()
			return
		}

		// Extract token from "Bearer <token>"
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			utils.UnauthorizedResponse(c, "Invalid authorization header format")
			c.Abort()
			return
		}

		token := parts[1]
		claims, err := utils.ParseToken(token, secret)
		if err != nil {
			utils.UnauthorizedResponse(c, "Invalid or expired token")
			c.Abort()
			return
		}

		// Set claims in context
		c.Set("user_id", claims.UserID)
		c.Set("tenant_id", claims.TenantID)
		c.Set("store_id", claims.StoreID)
		c.Set("role", claims.Role)

		c.Next()
	}
}

// RequireRole middleware checks if user has required role
func RequireRole(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userRole, exists := c.Get("role")
		if !exists {
			utils.ForbiddenResponse(c, "Role not found in context")
			c.Abort()
			return
		}

		role := userRole.(string)
		for _, r := range roles {
			if role == r {
				c.Next()
				return
			}
		}

		utils.ForbiddenResponse(c, "Insufficient permissions")
		c.Abort()
	}
}
