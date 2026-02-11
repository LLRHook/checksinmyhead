package models

import "time"

type TabMember struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	TabID       uint      `gorm:"not null;index" json:"tab_id"`
	DisplayName string    `gorm:"not null" json:"display_name"`
	MemberToken string    `gorm:"type:varchar(64);uniqueIndex" json:"-"`
	Role        string    `gorm:"type:varchar(20);default:'member'" json:"role"`
	JoinedAt    time.Time `json:"joined_at"`
}
