package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/config"
	"github.com/yourusername/pos-backend/internal/handler"
	"github.com/yourusername/pos-backend/internal/integration/creditcard"
	"github.com/yourusername/pos-backend/internal/integration/delivery"
	"github.com/yourusername/pos-backend/internal/integration/einvoice"
	"github.com/yourusername/pos-backend/internal/integration/linepay"
	"github.com/yourusername/pos-backend/internal/middleware"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
	"github.com/yourusername/pos-backend/internal/service"
	"go.uber.org/zap"
)

func main() {
	// Load configuration
	cfg, err := config.Load("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize logger
	logger, err := config.NewLogger(&cfg.Log)
	if err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}
	defer logger.Sync()

	logger.Info("Starting POS API Server")

	// Connect to PostgreSQL
	db, err := config.NewPostgresDB(&cfg.Database)
	if err != nil {
		logger.Fatal("Failed to connect to database", zap.Error(err))
	}

	// Connect to Redis
	redisClient, err := config.NewRedisClient(&cfg.Redis)
	if err != nil {
		logger.Fatal("Failed to connect to redis", zap.Error(err))
	}
	defer redisClient.Close()

	// Set Gin mode
	if cfg.Server.Mode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Initialize repositories
	employeeRepo := postgres.NewEmployeeRepository(db)
	menuRepo := postgres.NewMenuRepository(db)
	orderRepo := postgres.NewOrderRepository(db)
	tableRepo := postgres.NewTableRepository(db)
	warehouseRepo := postgres.NewWarehouseRepository(db)
	_ = postgres.NewInventoryRepository(db) // initialized for future use

	// Initialize payment gateways
	linePayGW := linepay.NewClient(linepay.Config{
		ChannelID:     cfg.Payment.LinePay.ChannelID,
		ChannelSecret: cfg.Payment.LinePay.ChannelSecret,
		IsSandbox:     cfg.Payment.LinePay.IsSandbox,
		MockMode:      cfg.Payment.MockMode,
	})
	creditCardGW := creditcard.NewClient(creditcard.Config{
		PartnerKey: cfg.Payment.TapPay.PartnerKey,
		MerchantID: cfg.Payment.TapPay.MerchantID,
		IsSandbox:  cfg.Payment.TapPay.IsSandbox,
		MockMode:   cfg.Payment.MockMode,
	})

	// Initialize e-invoice provider
	invoiceProvider := einvoice.NewProvider(einvoice.Config{
		Provider:    cfg.Invoice.Provider,
		MerchantID:  cfg.Invoice.ECPay.MerchantID,
		HashKey:     cfg.Invoice.ECPay.HashKey,
		HashIV:      cfg.Invoice.ECPay.HashIV,
		IsSandbox:   cfg.Invoice.ECPay.IsSandbox,
		MockMode:    cfg.Invoice.MockMode,
		SellerTaxID: cfg.Invoice.SellerTaxID,
		SellerName:  cfg.Invoice.SellerName,
	})

	// Initialize delivery platform clients
	deliveryCfg := delivery.Config{
		MockMode:       cfg.Delivery.MockMode,
		FoodpandaKey:   cfg.Delivery.FoodpandaKey,
		FoodpandaURL:   cfg.Delivery.FoodpandaURL,
		UberEatsID:     cfg.Delivery.UberEatsID,
		UberEatsSecret: cfg.Delivery.UberEatsSecret,
		UberEatsURL:    cfg.Delivery.UberEatsURL,
	}
	foodpandaGW := delivery.NewFoodpandaClient(deliveryCfg)
	uberEatsGW := delivery.NewUberEatsClient(deliveryCfg)

	// Resolve default store ID for delivery orders
	defaultStoreID, err := uuid.Parse(cfg.Delivery.DefaultStoreID)
	if err != nil {
		logger.Warn("Invalid delivery.default_store_id in config; using zero UUID", zap.Error(err))
		defaultStoreID = uuid.Nil
	}

	// Initialize services
	authService := service.NewAuthService(employeeRepo, cfg.JWT.Secret, cfg.JWT.ExpireHour)
	menuService := service.NewMenuService(menuRepo)
	orderService := service.NewOrderService(orderRepo, menuRepo, linePayGW, creditCardGW)
	tableService := service.NewTableService(tableRepo, orderRepo)
	reportService := service.NewReportService(orderRepo, menuRepo)
	invoiceService := service.NewInvoiceService(orderRepo, invoiceProvider)
	deliveryService := service.NewDeliveryService(orderRepo, menuRepo, foodpandaGW, uberEatsGW, defaultStoreID)
	warehouseService := service.NewWarehouseService(warehouseRepo)

	// Initialize handlers
	authHandler := handler.NewAuthHandler(authService)
	menuHandler := handler.NewMenuHandler(menuService)
	orderHandler := handler.NewOrderHandler(orderService)
	tableHandler := handler.NewTableHandler(tableService)
	reportHandler := handler.NewReportHandler(reportService)
	invoiceHandler := handler.NewInvoiceHandler(invoiceService)
	deliveryHandler := handler.NewDeliveryHandler(deliveryService)
	warehouseHandler := handler.NewWarehouseHandler(warehouseService)

	// Create Gin router
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.CORS())

	// Custom logger middleware
	router.Use(func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		duration := time.Since(start)
		logger.Info("HTTP Request",
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("duration", duration),
			zap.String("ip", c.ClientIP()),
		)
	})

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
			"time":   time.Now().Format(time.RFC3339),
		})
	})

	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Auth routes (public)
		auth := v1.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/pin-login", authHandler.PinLogin)
			auth.POST("/logout", authHandler.Logout)
		}

		// Protected routes (require authentication)
		protected := v1.Group("")
		protected.Use(middleware.AuthMiddleware(cfg.JWT.Secret))
		{
			// Test endpoint
			protected.GET("/ping", func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{
					"message": "pong (authenticated)",
				})
			})

			// Menu routes
			menu := protected.Group("/menu")
			{
				// Categories
				menu.GET("/categories", menuHandler.ListCategories)
				menu.GET("/categories/:id", menuHandler.GetCategory)
				menu.POST("/categories", menuHandler.CreateCategory)
				menu.PUT("/categories/:id", menuHandler.UpdateCategory)
				menu.DELETE("/categories/:id", menuHandler.DeleteCategory)

				// Menu Items
				menu.GET("/items", menuHandler.ListMenuItems)
				menu.GET("/items/:id", menuHandler.GetMenuItem)
				menu.GET("/items/barcode/:barcode", menuHandler.GetMenuItemByBarcode)
				menu.POST("/items", menuHandler.CreateMenuItem)
				menu.PUT("/items/:id", menuHandler.UpdateMenuItem)
				menu.DELETE("/items/:id", menuHandler.DeleteMenuItem)

				// Item Prices
				menu.GET("/items/:id/prices", menuHandler.ListItemPrices)
				menu.GET("/items/:id/prices/:store_id", menuHandler.GetItemPrice)
				menu.PUT("/items/:id/prices/:store_id", menuHandler.SetItemPrice)
			}

			// Order routes
			orders := protected.Group("/orders")
			{
				orders.GET("", orderHandler.ListOrders)
				orders.GET("/:id", orderHandler.GetOrder)
				orders.POST("", orderHandler.CreateOrder)
				orders.PUT("/:id", orderHandler.UpdateOrder)
				orders.PUT("/:id/status", orderHandler.UpdateOrderStatus)
				orders.POST("/:id/cancel", orderHandler.CancelOrder)
				orders.POST("/:id/items", orderHandler.AddOrderItem)
				orders.POST("/:id/payments", orderHandler.AddPayment)
				orders.POST("/:id/payments/gateway", orderHandler.InitiateGatewayPayment)
				orders.POST("/:id/payments/gateway/confirm", orderHandler.ConfirmGatewayPayment)

				// Invoice routes
				orders.POST("/:id/invoice", invoiceHandler.IssueInvoice)
				orders.GET("/:id/invoice", invoiceHandler.GetInvoice)
				orders.POST("/:id/invoice/void", invoiceHandler.VoidInvoice)

				// Sales reports
				orders.GET("/sales/daily", orderHandler.GetDailySales)
			}

			// Table routes
			tables := protected.Group("/tables")
			{
				tables.GET("/available", tableHandler.GetAvailableTables)
				tables.GET("/occupied", tableHandler.GetOccupiedTables)
				tables.GET("/stats", tableHandler.GetTableStats)
				tables.GET("/areas", tableHandler.GetAreaList)
				tables.POST("/transfer", tableHandler.TransferTable)
				tables.GET("", tableHandler.ListTables)
				tables.GET("/:id", tableHandler.GetTable)
				tables.GET("/:id/orders", tableHandler.GetTableWithOrders)
				tables.POST("", tableHandler.CreateTable)
				tables.PUT("/:id", tableHandler.UpdateTable)
				tables.PUT("/:id/status", tableHandler.UpdateTableStatus)
				tables.DELETE("/:id", tableHandler.DeleteTable)
			}

			// Report routes
			reports := protected.Group("/reports")
			{
				reports.GET("/summary", reportHandler.GetSalesSummary)
				reports.GET("/sales/daily", reportHandler.GetDailySalesReport)
				reports.GET("/sales/weekly", reportHandler.GetWeeklySalesReport)
				reports.GET("/sales/monthly", reportHandler.GetMonthlySalesReport)
				reports.GET("/sales/custom", reportHandler.GetCustomSalesReport)
				reports.GET("/sales/hourly", reportHandler.GetHourlySales)
				reports.GET("/products/ranking", reportHandler.GetProductSalesRanking)
				reports.GET("/categories/sales", reportHandler.GetCategorySales)
			}

			// Delivery platform routes
			// POST /delivery/orders  — webhook from Foodpanda / Uber Eats (or manual for mock mode)
			// POST /delivery/status  — push status update to delivery platform
			deliveryGroup := protected.Group("/delivery")
			{
				deliveryGroup.POST("/orders", deliveryHandler.ReceiveOrder)
				deliveryGroup.POST("/status", deliveryHandler.UpdateStatus)
			}

			warehouse := protected.Group("/warehouse")
			{
				warehouse.GET("/zone-templates", warehouseHandler.ListZoneTemplates)
				warehouse.POST("/zone-templates", warehouseHandler.CreateZoneTemplate)
				warehouse.PUT("/zone-templates/:id", warehouseHandler.UpdateZoneTemplate)
				warehouse.DELETE("/zone-templates/:id", warehouseHandler.DeleteZoneTemplate)

				warehouse.GET("/tare-containers", warehouseHandler.ListTareContainers)
				warehouse.POST("/tare-containers", warehouseHandler.CreateTareContainer)
				warehouse.PUT("/tare-containers/:id", warehouseHandler.UpdateTareContainer)
				warehouse.DELETE("/tare-containers/:id", warehouseHandler.DeleteTareContainer)

				warehouse.GET("/monthly-records", warehouseHandler.GetMonthlyRecord)
				warehouse.POST("/monthly-records/:id/complete", warehouseHandler.CompleteMonthlyRecord)
				warehouse.POST("/monthly-zones/:zone_id/items", warehouseHandler.CreateMonthlyItem)
				warehouse.PUT("/monthly-items/:id", warehouseHandler.UpdateMonthlyItem)
				warehouse.DELETE("/monthly-items/:id", warehouseHandler.DeleteMonthlyItem)
			}
		}
	}

	// Create HTTP server
	addr := fmt.Sprintf(":%s", cfg.Server.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Start server in a goroutine
	go func() {
		logger.Info("Server starting", zap.String("address", addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Failed to start server", zap.Error(err))
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", zap.Error(err))
	}

	// Close database connection
	sqlDB, _ := db.DB()
	if sqlDB != nil {
		sqlDB.Close()
	}

	logger.Info("Server exited")
}
