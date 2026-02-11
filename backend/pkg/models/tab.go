package models

import (
	"time"
)

type Tab struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	Name        string    `gorm:"not null" json:"name"`
	Description string    `json:"description"`
	Bills       []Bill    `gorm:"foreignKey:TabID" json:"bills"`
	TotalAmount float64   `gorm:"-" json:"total_amount"`
	AccessToken string    `gorm:"type:varchar(64);uniqueIndex" json:"access_token,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}
