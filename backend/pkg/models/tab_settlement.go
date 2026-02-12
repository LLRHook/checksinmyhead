package models

import "time"

type TabSettlement struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	TabID      uint      `gorm:"not null;index" json:"tab_id"`
	PersonName string    `gorm:"not null" json:"person_name"`
	Amount     float64   `gorm:"not null" json:"amount"`
	Paid       bool      `gorm:"default:false" json:"paid"`
	CreatedAt  time.Time `json:"created_at"`
}
