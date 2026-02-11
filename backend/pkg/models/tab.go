package models

import (
	"time"
)

type Tab struct {
	ID          uint       `gorm:"primaryKey" json:"id"`
	Name        string     `gorm:"not null" json:"name"`
	Description string     `json:"description"`
	Bills       []Bill      `gorm:"foreignKey:TabID" json:"bills"`
	Members     []TabMember `gorm:"foreignKey:TabID" json:"members,omitempty"`
	TotalAmount float64    `gorm:"-" json:"total_amount"`
	Finalized   bool       `gorm:"default:false" json:"finalized"`
	FinalizedAt *time.Time `json:"finalized_at"`
	AccessToken string     `gorm:"type:varchar(64);uniqueIndex" json:"access_token,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}
