package database

import (
	"backend/pkg/models"
	"fmt"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func InitDB() (*gorm.DB, error) {
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	name := os.Getenv("DB_NAME")
	user := os.Getenv("DB_USER")
	pw := os.Getenv("DB_PASSWORD")
	sslmode := os.Getenv("DB_SSLMODE")

	if host == "" || port == "" || name == "" || user == "" || pw == "" {
		return nil, fmt.Errorf("missing required database environment variables")
	}

	if sslmode == "" {
		sslmode = "require"
	}

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=America/New_York", host, user, pw, name, port, sslmode)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// Migrate parent tables first (Tab before Bill, since Bill has FK to Tab)
	err = db.AutoMigrate(&models.Tab{}, &models.TabMember{}, &models.TabImage{}, &models.TabSettlement{}, &models.Bill{}, &models.Person{}, &models.BillItem{}, &models.ItemAssignment{}, &models.PersonShare{})
	if err != nil {
		return nil, err
	}

	return db, nil
}
