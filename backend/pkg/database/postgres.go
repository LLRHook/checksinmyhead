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

	if host == "" || port == "" || name == "" || user == "" || pw == "" {
		return nil, fmt.Errorf("missing required database environment variables")
	}

	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=America/New_York", host, user, pw, name, port)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	err = db.AutoMigrate(&models.Bill{}, &models.Person{}, &models.BillItem{}, &models.ItemAssignment{})
	if err != nil {
		return nil, err
	}

	return db, nil
}
