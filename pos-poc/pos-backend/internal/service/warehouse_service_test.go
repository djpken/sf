package service

import (
	"fmt"
	"testing"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func newTestWarehouseService(t *testing.T) (*WarehouseService, uuid.UUID) {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(fmt.Sprintf("file:%s?mode=memory&cache=shared", uuid.NewString())), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	migrateWarehouseTestSchema(t, db)
	return NewWarehouseService(postgres.NewWarehouseRepository(db)), uuid.New()
}

func migrateWarehouseTestSchema(t *testing.T, db *gorm.DB) {
	t.Helper()
	statements := []string{
		`CREATE TABLE warehouse_zone_templates (
			id text primary key,
			store_id text not null,
			store_area text not null,
			name text not null,
			is_active boolean default true,
			created_at datetime,
			updated_at datetime
		)`,
		`CREATE TABLE warehouse_tare_containers (
			id text primary key,
			store_id text not null,
			name text not null,
			grams integer not null,
			is_active boolean default true,
			created_at datetime,
			updated_at datetime
		)`,
		`CREATE TABLE monthly_inventory_records (
			id text primary key,
			store_id text not null,
			store_area text not null,
			year_month text not null,
			is_completed boolean default false,
			created_at datetime,
			updated_at datetime,
			unique(store_id, store_area, year_month)
		)`,
		`CREATE TABLE monthly_inventory_zones (
			id text primary key,
			record_id text not null,
			zone_template_id text,
			name_snapshot text not null,
			created_at datetime,
			updated_at datetime
		)`,
		`CREATE TABLE monthly_inventory_items (
			id text primary key,
			zone_id text not null,
			name text not null,
			measurement_type text not null,
			value real not null,
			note text,
			created_at datetime,
			updated_at datetime
		)`,
	}
	for _, stmt := range statements {
		if err := db.Exec(stmt).Error; err != nil {
			t.Fatalf("create test schema: %v", err)
		}
	}
}

func TestWarehouseMonthlyRecordKeepsHistoricalZoneItemsAfterSoftDelete(t *testing.T) {
	svc, storeID := newTestWarehouseService(t)

	template, err := svc.CreateZoneTemplate(storeID, ZoneTemplateRequest{
		StoreArea: domain.WarehouseStoreAreaFront,
		Name:      "四門",
	})
	if err != nil {
		t.Fatalf("create template: %v", err)
	}

	may, err := svc.LoadOrCreateMonthlyRecord(storeID, domain.WarehouseStoreAreaFront, "2026-05")
	if err != nil {
		t.Fatalf("load may: %v", err)
	}
	if len(may.Zones) != 1 || may.Zones[0].NameSnapshot != "四門" {
		t.Fatalf("expected one 四門 zone, got %+v", may.Zones)
	}

	if _, err := svc.CreateMonthlyItem(storeID, may.Zones[0].ID, MonthlyItemRequest{
		Name:            "鮮奶",
		MeasurementType: domain.WarehouseMeasurementQuantity,
		Value:           3,
	}); err != nil {
		t.Fatalf("create item: %v", err)
	}

	if err := svc.DeleteZoneTemplate(storeID, template.ID); err != nil {
		t.Fatalf("soft delete template: %v", err)
	}

	mayAgain, err := svc.LoadOrCreateMonthlyRecord(storeID, domain.WarehouseStoreAreaFront, "2026-05")
	if err != nil {
		t.Fatalf("reload may: %v", err)
	}
	if len(mayAgain.Zones) != 1 || len(mayAgain.Zones[0].Items) != 1 {
		t.Fatalf("expected historical zone item to remain, got %+v", mayAgain.Zones)
	}

	june, err := svc.LoadOrCreateMonthlyRecord(storeID, domain.WarehouseStoreAreaFront, "2026-06")
	if err != nil {
		t.Fatalf("load june: %v", err)
	}
	if len(june.Zones) != 0 {
		t.Fatalf("expected deleted template to be skipped for new month, got %+v", june.Zones)
	}
}

func TestWarehouseTareContainersAreStoreScopedAndSoftDeleted(t *testing.T) {
	svc, storeID := newTestWarehouseService(t)
	otherStoreID := uuid.New()

	container, err := svc.CreateTareContainer(storeID, TareContainerRequest{
		Name:  "湯桶",
		Grams: 850,
	})
	if err != nil {
		t.Fatalf("create container: %v", err)
	}

	other, err := svc.ListTareContainers(otherStoreID)
	if err != nil {
		t.Fatalf("list other store: %v", err)
	}
	if len(other) != 0 {
		t.Fatalf("expected other store isolation, got %+v", other)
	}

	if err := svc.DeleteTareContainer(storeID, container.ID); err != nil {
		t.Fatalf("delete container: %v", err)
	}
	containers, err := svc.ListTareContainers(storeID)
	if err != nil {
		t.Fatalf("list containers: %v", err)
	}
	if len(containers) != 0 {
		t.Fatalf("expected soft-deleted container hidden, got %+v", containers)
	}
}
