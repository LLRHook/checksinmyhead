package models

import "time"

type TabSettlement struct {
	GuestBillID     uint      `gorm:"-" json:"-"`
	ViewerMemberID  *uint     `gorm:"-" json:"-"`
	SnapshotVersion int16     `gorm:"not null;default:1" json:"-"`
	MemberID        *uint     `json:"-"`
	ParticipantID   *uint     `json:"-"`
	ID              uint      `gorm:"primaryKey" json:"id"`
	TabID           uint      `gorm:"not null;index" json:"tab_id"`
	PersonName      string    `gorm:"not null" json:"person_name"`
	Amount          float64   `gorm:"not null" json:"amount"`
	Paid            bool      `gorm:"default:false" json:"paid"`
	CreatedAt       time.Time `json:"created_at"`
}
