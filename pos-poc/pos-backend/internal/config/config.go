package config

import (
	"fmt"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	Log      LogConfig
	Payment  PaymentConfig
	Invoice  InvoiceConfig
	Delivery DeliveryConfig
}

// DeliveryConfig holds configuration for delivery platform integrations.
type DeliveryConfig struct {
	MockMode       bool   `mapstructure:"mock_mode"`
	DefaultStoreID string `mapstructure:"default_store_id"` // store to assign incoming delivery orders
	FoodpandaKey   string `mapstructure:"foodpanda_key"`
	FoodpandaURL   string `mapstructure:"foodpanda_url"`
	UberEatsID     string `mapstructure:"uber_eats_id"`
	UberEatsSecret string `mapstructure:"uber_eats_secret"`
	UberEatsURL    string `mapstructure:"uber_eats_url"`
}

// InvoiceConfig holds configuration for e-invoice provider integration.
type InvoiceConfig struct {
	MockMode    bool   `mapstructure:"mock_mode"`
	Provider    string `mapstructure:"provider"` // "mock" or "ecpay"
	SellerTaxID string `mapstructure:"seller_tax_id"`
	SellerName  string `mapstructure:"seller_name"`
	ECPay       ECPayInvoiceConfig
}

// ECPayInvoiceConfig holds ECPay e-invoice credentials.
type ECPayInvoiceConfig struct {
	MerchantID string `mapstructure:"merchant_id"`
	HashKey    string `mapstructure:"hash_key"`
	HashIV     string `mapstructure:"hash_iv"`
	IsSandbox  bool   `mapstructure:"is_sandbox"`
}

// PaymentConfig holds configuration for payment gateway integrations.
type PaymentConfig struct {
	MockMode  bool   `mapstructure:"mock_mode"`
	ReturnURL string `mapstructure:"return_url"`
	LinePay   LinePayConfig
	TapPay    TapPayConfig
}

// LinePayConfig holds Line Pay gateway credentials.
type LinePayConfig struct {
	ChannelID     string `mapstructure:"channel_id"`
	ChannelSecret string `mapstructure:"channel_secret"`
	IsSandbox     bool   `mapstructure:"is_sandbox"`
}

// TapPayConfig holds TapPay (credit card) gateway credentials.
type TapPayConfig struct {
	PartnerKey string `mapstructure:"partner_key"`
	MerchantID string `mapstructure:"merchant_id"`
	IsSandbox  bool   `mapstructure:"is_sandbox"`
}

type ServerConfig struct {
	Port         string
	Mode         string // debug, release, test
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
}

type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
	Timezone string
}

type RedisConfig struct {
	Host     string
	Port     int
	Password string
	DB       int
}

type JWTConfig struct {
	Secret     string
	ExpireHour int
}

type LogConfig struct {
	Level      string
	OutputPath string
}

// Load loads configuration from file and environment variables
func Load(configPath string) (*Config, error) {
	viper.SetConfigFile(configPath)
	viper.AutomaticEnv()

	// Set defaults
	setDefaults()

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &config, nil
}

func setDefaults() {
	// Server defaults
	viper.SetDefault("server.port", "8080")
	viper.SetDefault("server.mode", "debug")
	viper.SetDefault("server.readTimeout", "10s")
	viper.SetDefault("server.writeTimeout", "10s")

	// Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.user", "pos")
	viper.SetDefault("database.password", "pos_password")
	viper.SetDefault("database.dbname", "pos_db")
	viper.SetDefault("database.sslmode", "disable")
	viper.SetDefault("database.timezone", "Asia/Taipei")

	// Redis defaults
	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", 6379)
	viper.SetDefault("redis.password", "")
	viper.SetDefault("redis.db", 0)

	// JWT defaults
	viper.SetDefault("jwt.secret", "your-secret-key-change-in-production")
	viper.SetDefault("jwt.expireHour", 24)

	// Log defaults
	viper.SetDefault("log.level", "debug")
	viper.SetDefault("log.outputPath", "logs/app.log")

	// Payment defaults
	viper.SetDefault("payment.mock_mode", true)
	viper.SetDefault("payment.return_url", "http://localhost:8080/api/v1/orders/payments/callback")
	viper.SetDefault("payment.line_pay.is_sandbox", true)
	viper.SetDefault("payment.tap_pay.is_sandbox", true)

	// Invoice defaults
	viper.SetDefault("invoice.mock_mode", true)
	viper.SetDefault("invoice.provider", "mock")
	viper.SetDefault("invoice.ecpay.is_sandbox", true)

	// Delivery defaults
	viper.SetDefault("delivery.mock_mode", true)
	viper.SetDefault("delivery.default_store_id", "22222222-2222-2222-2222-222222222221")
}

// GetDSN returns PostgreSQL connection string
func (c *DatabaseConfig) GetDSN() string {
	return fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s TimeZone=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode, c.Timezone,
	)
}
