package image

import (
	"backend/pkg/models"

	"gorm.io/gorm"
)

type ImageRepository interface {
	Create(image *models.TabImage) error
	GetByTabID(tabID uint) ([]models.TabImage, error)
	GetByID(id uint) (*models.TabImage, error)
	UpdateProcessed(id uint, processed bool) error
	Delete(id uint) error
}

type imageRepository struct {
	db *gorm.DB
}

func (r *imageRepository) Create(image *models.TabImage) error {
	return r.db.Create(image).Error
}

func (r *imageRepository) GetByTabID(tabID uint) ([]models.TabImage, error) {
	var images []models.TabImage
	err := r.db.Where("tab_id = ?", tabID).Order("created_at DESC").Find(&images).Error
	return images, err
}

func (r *imageRepository) GetByID(id uint) (*models.TabImage, error) {
	image := &models.TabImage{}
	err := r.db.First(image, id).Error
	return image, err
}

func (r *imageRepository) UpdateProcessed(id uint, processed bool) error {
	return r.db.Model(&models.TabImage{}).Where("id = ?", id).Update("processed", processed).Error
}

func (r *imageRepository) Delete(id uint) error {
	return r.db.Delete(&models.TabImage{}, id).Error
}

func NewImageRepository(db *gorm.DB) ImageRepository {
	return &imageRepository{db: db}
}
