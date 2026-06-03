-- Drop triggers
DROP TRIGGER IF EXISTS update_inventory_updated_at ON inventory;
DROP TRIGGER IF EXISTS update_invoices_updated_at ON invoices;
DROP TRIGGER IF EXISTS update_order_items_updated_at ON order_items;
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS update_tables_updated_at ON tables;
DROP TRIGGER IF EXISTS update_menu_item_prices_updated_at ON menu_item_prices;
DROP TRIGGER IF EXISTS update_menu_items_updated_at ON menu_items;
DROP TRIGGER IF EXISTS update_menu_categories_updated_at ON menu_categories;
DROP TRIGGER IF EXISTS update_employees_updated_at ON employees;
DROP TRIGGER IF EXISTS update_stores_updated_at ON stores;
DROP TRIGGER IF EXISTS update_tenants_updated_at ON tenants;

-- Drop trigger function
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Drop indexes
DROP INDEX IF EXISTS idx_inventory_item;
DROP INDEX IF EXISTS idx_inventory_store;
DROP INDEX IF EXISTS idx_invoices_order;
DROP INDEX IF EXISTS idx_payments_order;
DROP INDEX IF EXISTS idx_order_items_order;
DROP INDEX IF EXISTS idx_orders_order_no;
DROP INDEX IF EXISTS idx_orders_status;
DROP INDEX IF EXISTS idx_orders_store_date;
DROP INDEX IF EXISTS idx_orders_store;
DROP INDEX IF EXISTS idx_tables_store;
DROP INDEX IF EXISTS idx_menu_item_prices_store;
DROP INDEX IF EXISTS idx_menu_item_prices_item;
DROP INDEX IF EXISTS idx_menu_items_barcode;
DROP INDEX IF EXISTS idx_menu_items_category;
DROP INDEX IF EXISTS idx_menu_items_tenant;
DROP INDEX IF EXISTS idx_menu_categories_tenant;
DROP INDEX IF EXISTS idx_employees_pin;
DROP INDEX IF EXISTS idx_employees_store;
DROP INDEX IF EXISTS idx_employees_tenant;
DROP INDEX IF EXISTS idx_stores_tenant;

-- Drop tables (in reverse order of creation due to foreign keys)
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS tables;
DROP TABLE IF EXISTS menu_item_prices;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS menu_categories;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS tenants;

-- Drop extension
DROP EXTENSION IF EXISTS "uuid-ossp";
