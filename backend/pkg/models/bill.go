package models

import (
	"time"

	"gorm.io/gorm"
)

// PaymentMethod represents the bill creator's payment method.
type PaymentMethod struct {
	Name       string `json:"name"`
	Identifier string `json:"identifier"`
}

// Person represents a participant in a bill.
type Person struct {
	ID   uint   `gorm:"primaryKey" json:"id"`
	Name string `gorm:"not null" json:"name"`
}

// BillItem represents an item on a bill with its cost.
type BillItem struct {
	ID          uint             `gorm:"primaryKey" json:"id"`
	BillID      uint             `gorm:"not null;index" json:"bill_id"`
	Name        string           `gorm:"not null" json:"name"`
	Price       float64          `gorm:"not null" json:"price"`
	Assignments []ItemAssignment `gorm:"constraint:OnDelete:CASCADE" json:"assignments"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
}

// ItemAssignment represents the percentage assignment of a bill item to a person.
type ItemAssignment struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	BillItemID uint      `gorm:"not null;index" json:"bill_item_id"`
	PersonID   uint      `gorm:"not null;index" json:"person_id"`
	Percentage float64   `gorm:"not null" json:"percentage"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// Bill represents a complete bill with participants, items, and financial details.
type Bill struct {
	ID            uint          `gorm:"primaryKey" json:"id"`
	Name          string        `gorm:"not null" json:"name"`
	Subtotal      float64       `gorm:"not null" json:"subtotal"`
	Tax           float64       `gorm:"not null" json:"tax"`
	TipAmount     float64       `gorm:"not null" json:"tip_amount"`
	TipPercentage float64       `json:"tip_percentage"`
	Total         float64       `gorm:"not null" json:"total"`
	Date          time.Time     `gorm:"not null" json:"date"`
	PaymentMethod PaymentMethod `gorm:"type:jsonb;serializer:json" json:"payment_method"`
	Participants  []Person      `gorm:"many2many:bill_participants;constraint:OnDelete:SET NULL" json:"participants"`
	Items         []BillItem    `gorm:"constraint:OnDelete:CASCADE" json:"items"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
	AccessToken string `gorm:"type:varchar(64);uniqueIndex" json:"access_token,omitempty"`
}

// BeforeCreate hook to set default values before creating a Bill.
func (b *Bill) BeforeCreate(tx *gorm.DB) error {
	if b.Date.IsZero() {
		b.Date = time.Now()
	}
	return nil
}
