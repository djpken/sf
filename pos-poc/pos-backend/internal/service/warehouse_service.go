package service

import (
	"errors"
	"regexp"

	"github.com/google/uuid"
	"github.com/yourusername/pos-backend/internal/domain"
	"github.com/yourusername/pos-backend/internal/repository/postgres"
)

var yearMonthPattern = regexp.MustCompile(`^\d{4}-\d{2}$`)

type WarehouseService struct {
	repo *postgres.WarehouseRepository
}

func NewWarehouseService(repo *postgres.WarehouseRepository) *WarehouseService {
	return &WarehouseService{repo: repo}
}

type ZoneTemplateRequest struct {
	StoreArea domain.WarehouseStoreArea `json:"store_area" binding:"required"`
	Name      string                    `json:"name" binding:"required"`
}

type UpdateZoneTemplateRequest struct {
	Name *string `json:"name,omitempty"`
}

type TareContainerRequest struct {
	Name  string `json:"name" binding:"required"`
	Grams int    `json:"grams" binding:"required,gt=0"`
}

type UpdateTareContainerRequest struct {
	Name  *string `json:"name,omitempty"`
	Grams *int    `json:"grams,omitempty"`
}

type MonthlyItemRequest struct {
	Name            string                          `json:"name" binding:"required"`
	MeasurementType domain.WarehouseMeasurementType `json:"measurement_type" binding:"required"`
	Value           float64                         `json:"value" binding:"required,gte=0"`
	Note            *string                         `json:"note,omitempty"`
}

func (s *WarehouseService) ListZoneTemplates(storeID uuid.UUID, storeArea domain.WarehouseStoreArea) ([]domain.WarehouseZoneTemplate, error) {
	if !validStoreArea(storeArea) {
		return nil, errors.New("invalid store_area")
	}
	return s.repo.ListZoneTemplates(storeID, storeArea)
}

func (s *WarehouseService) CreateZoneTemplate(storeID uuid.UUID, req ZoneTemplateRequest) (*domain.WarehouseZoneTemplate, error) {
	if !validStoreArea(req.StoreArea) {
		return nil, errors.New("invalid store_area")
	}
	template := &domain.WarehouseZoneTemplate{
		StoreID:   storeID,
		StoreArea: req.StoreArea,
		Name:      req.Name,
		IsActive:  true,
	}
	if err := s.repo.CreateZoneTemplate(template); err != nil {
		return nil, err
	}
	return template, nil
}

func (s *WarehouseService) UpdateZoneTemplate(storeID, id uuid.UUID, req UpdateZoneTemplateRequest) (*domain.WarehouseZoneTemplate, error) {
	template, err := s.repo.FindZoneTemplate(storeID, id)
	if err != nil {
		return nil, err
	}
	if template == nil {
		return nil, errors.New("zone template not found")
	}
	if req.Name != nil {
		template.Name = *req.Name
	}
	if err := s.repo.UpdateZoneTemplate(template); err != nil {
		return nil, err
	}
	return template, nil
}

func (s *WarehouseService) DeleteZoneTemplate(storeID, id uuid.UUID) error {
	template, err := s.repo.FindZoneTemplate(storeID, id)
	if err != nil {
		return err
	}
	if template == nil {
		return errors.New("zone template not found")
	}
	template.IsActive = false
	return s.repo.UpdateZoneTemplate(template)
}

func (s *WarehouseService) ListTareContainers(storeID uuid.UUID) ([]domain.WarehouseTareContainer, error) {
	return s.repo.ListTareContainers(storeID)
}

func (s *WarehouseService) CreateTareContainer(storeID uuid.UUID, req TareContainerRequest) (*domain.WarehouseTareContainer, error) {
	container := &domain.WarehouseTareContainer{
		StoreID:  storeID,
		Name:     req.Name,
		Grams:    req.Grams,
		IsActive: true,
	}
	if err := s.repo.CreateTareContainer(container); err != nil {
		return nil, err
	}
	return container, nil
}

func (s *WarehouseService) UpdateTareContainer(storeID, id uuid.UUID, req UpdateTareContainerRequest) (*domain.WarehouseTareContainer, error) {
	container, err := s.repo.FindTareContainer(storeID, id)
	if err != nil {
		return nil, err
	}
	if container == nil {
		return nil, errors.New("tare container not found")
	}
	if req.Name != nil {
		container.Name = *req.Name
	}
	if req.Grams != nil {
		if *req.Grams <= 0 {
			return nil, errors.New("grams must be greater than 0")
		}
		container.Grams = *req.Grams
	}
	if err := s.repo.UpdateTareContainer(container); err != nil {
		return nil, err
	}
	return container, nil
}

func (s *WarehouseService) DeleteTareContainer(storeID, id uuid.UUID) error {
	container, err := s.repo.FindTareContainer(storeID, id)
	if err != nil {
		return err
	}
	if container == nil {
		return errors.New("tare container not found")
	}
	container.IsActive = false
	return s.repo.UpdateTareContainer(container)
}

func (s *WarehouseService) LoadOrCreateMonthlyRecord(storeID uuid.UUID, storeArea domain.WarehouseStoreArea, yearMonth string) (*domain.MonthlyInventoryRecord, error) {
	if !validStoreArea(storeArea) {
		return nil, errors.New("invalid store_area")
	}
	if !yearMonthPattern.MatchString(yearMonth) {
		return nil, errors.New("year_month must use YYYY-MM format")
	}
	return s.repo.LoadOrCreateMonthlyRecord(storeID, storeArea, yearMonth)
}

func (s *WarehouseService) CompleteMonthlyRecord(storeID, id uuid.UUID) (*domain.MonthlyInventoryRecord, error) {
	record, err := s.repo.FindMonthlyRecord(storeID, id)
	if err != nil {
		return nil, err
	}
	if record == nil {
		return nil, errors.New("monthly record not found")
	}
	if err := s.repo.CompleteMonthlyRecord(record); err != nil {
		return nil, err
	}
	record.IsCompleted = true
	return record, nil
}

func (s *WarehouseService) CreateMonthlyItem(storeID, zoneID uuid.UUID, req MonthlyItemRequest) (*domain.MonthlyInventoryItem, error) {
	if !validMeasurementType(req.MeasurementType) {
		return nil, errors.New("invalid measurement_type")
	}
	zone, err := s.repo.FindMonthlyZoneByStore(storeID, zoneID)
	if err != nil {
		return nil, err
	}
	if zone == nil {
		return nil, errors.New("monthly zone not found")
	}
	item := &domain.MonthlyInventoryItem{
		ZoneID:          zone.ID,
		Name:            req.Name,
		MeasurementType: req.MeasurementType,
		Value:           req.Value,
		Note:            req.Note,
	}
	if err := s.repo.CreateMonthlyItem(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *WarehouseService) UpdateMonthlyItem(storeID, itemID uuid.UUID, req MonthlyItemRequest) (*domain.MonthlyInventoryItem, error) {
	if !validMeasurementType(req.MeasurementType) {
		return nil, errors.New("invalid measurement_type")
	}
	item, err := s.repo.FindMonthlyItemByStore(storeID, itemID)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, errors.New("monthly item not found")
	}
	item.Name = req.Name
	item.MeasurementType = req.MeasurementType
	item.Value = req.Value
	item.Note = req.Note
	if err := s.repo.UpdateMonthlyItem(item); err != nil {
		return nil, err
	}
	return item, nil
}

func (s *WarehouseService) DeleteMonthlyItem(storeID, itemID uuid.UUID) error {
	item, err := s.repo.FindMonthlyItemByStore(storeID, itemID)
	if err != nil {
		return err
	}
	if item == nil {
		return errors.New("monthly item not found")
	}
	return s.repo.DeleteMonthlyItem(item)
}

func validStoreArea(area domain.WarehouseStoreArea) bool {
	return area == domain.WarehouseStoreAreaFront ||
		area == domain.WarehouseStoreAreaBack ||
		area == domain.WarehouseStoreAreaBoth
}

func validMeasurementType(t domain.WarehouseMeasurementType) bool {
	return t == domain.WarehouseMeasurementWeight ||
		t == domain.WarehouseMeasurementQuantity ||
		t == domain.WarehouseMeasurementVolume
}
