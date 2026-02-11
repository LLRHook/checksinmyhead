package image

import (
	"backend/pkg/models"
	"fmt"
	"os"
	"path/filepath"
)

type ImageService interface {
	Create(image *models.TabImage) error
	GetByTabID(tabID uint) ([]models.TabImage, error)
	GetByID(id uint) (*models.TabImage, error)
	UpdateProcessed(id uint, processed bool) error
	Delete(id uint, uploadDir string) error
}

type imageService struct {
	repo ImageRepository
}

func (s *imageService) Create(image *models.TabImage) error {
	return s.repo.Create(image)
}

func (s *imageService) GetByTabID(tabID uint) ([]models.TabImage, error) {
	return s.repo.GetByTabID(tabID)
}

func (s *imageService) GetByID(id uint) (*models.TabImage, error) {
	return s.repo.GetByID(id)
}

func (s *imageService) UpdateProcessed(id uint, processed bool) error {
	return s.repo.UpdateProcessed(id, processed)
}

func (s *imageService) Delete(id uint, uploadDir string) error {
	image, err := s.repo.GetByID(id)
	if err != nil {
		return err
	}

	// Delete file from disk
	filePath := filepath.Join(uploadDir, "tabs", fmt.Sprintf("%d", image.TabID), image.Filename)
	os.Remove(filePath) // best-effort file deletion

	return s.repo.Delete(id)
}

func NewImageService(repo ImageRepository) ImageService {
	return &imageService{repo: repo}
}
