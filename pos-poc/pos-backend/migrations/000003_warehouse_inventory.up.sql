CREATE TABLE warehouse_zone_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    store_area VARCHAR(20) NOT NULL CHECK (store_area IN ('front', 'back', 'both')),
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE warehouse_tare_containers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    grams INT NOT NULL CHECK (grams > 0),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE monthly_inventory_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    store_area VARCHAR(20) NOT NULL CHECK (store_area IN ('front', 'back', 'both')),
    year_month VARCHAR(7) NOT NULL,
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, store_area, year_month)
);

CREATE TABLE monthly_inventory_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    record_id UUID NOT NULL REFERENCES monthly_inventory_records(id) ON DELETE CASCADE,
    zone_template_id UUID REFERENCES warehouse_zone_templates(id) ON DELETE SET NULL,
    name_snapshot VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE monthly_inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id UUID NOT NULL REFERENCES monthly_inventory_zones(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    measurement_type VARCHAR(20) NOT NULL CHECK (measurement_type IN ('weight', 'quantity', 'volume')),
    value DECIMAL(10,3) NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_warehouse_zone_templates_store_area ON warehouse_zone_templates(store_id, store_area);
CREATE INDEX idx_warehouse_tare_containers_store ON warehouse_tare_containers(store_id);
CREATE INDEX idx_monthly_inventory_records_store_month ON monthly_inventory_records(store_id, store_area, year_month);
CREATE INDEX idx_monthly_inventory_zones_record ON monthly_inventory_zones(record_id);
CREATE INDEX idx_monthly_inventory_items_zone ON monthly_inventory_items(zone_id);

CREATE TRIGGER update_warehouse_zone_templates_updated_at BEFORE UPDATE ON warehouse_zone_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_warehouse_tare_containers_updated_at BEFORE UPDATE ON warehouse_tare_containers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_monthly_inventory_records_updated_at BEFORE UPDATE ON monthly_inventory_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_monthly_inventory_zones_updated_at BEFORE UPDATE ON monthly_inventory_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_monthly_inventory_items_updated_at BEFORE UPDATE ON monthly_inventory_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
