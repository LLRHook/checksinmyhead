package models

import "time"

type TabImage struct {
	ID         uint      `gorm:"primaryKey" json:"id"`
	TabID      uint      `gorm:"not null;index" json:"tab_id"`
	Filename   string    `gorm:"not null" json:"filename"`
	URL        string    `gorm:"not null" json:"url"`
	Size       int64     `gorm:"not null" json:"size"`
	MimeType   string    `gorm:"not null" json:"mime_type"`
	Processed  bool      `gorm:"default:false" json:"processed"`
	UploadedBy string    `json:"uploaded_by"`
	CreatedAt  time.Time `json:"created_at"`
}
