package tab

import (
	"backend/pkg/models"
	"errors"
	"testing"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func newTabRepositoryTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.Tab{}, &models.Bill{}, &models.BillItem{}, &models.ItemAssignment{}, &models.PersonShare{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestUpdateBillItemAssignmentsRejectsChangesToPaidShares(t *testing.T) {
	db := newTabRepositoryTestDB(t)
	tab := models.Tab{Name: "Trip"}
	if err := db.Create(&tab).Error; err != nil {
		t.Fatal(err)
	}
	bill := models.Bill{TabID: &tab.ID, Name: "Receipt", Subtotal: 6, Total: 6, Date: time.Now()}
	if err := db.Create(&bill).Error; err != nil {
		t.Fatal(err)
	}
	item := models.BillItem{BillID: bill.ID, Name: "Beer", Price: 6, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}
	if err := db.Create(&item).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&models.PersonShare{BillID: bill.ID, PersonName: "Alex", Subtotal: 6, Total: 6, Paid: true}).Error; err != nil {
		t.Fatal(err)
	}

	err := (&tabRepository{db: db}).UpdateBillItemAssignments(tab.ID, bill.ID, item.ID, []models.ItemAssignment{{PersonName: "Sam", Percentage: 100}}, nil)
	if !errors.Is(err, ErrItemAlreadyPaid) {
		t.Fatalf("expected paid share assignment rejection, got %v", err)
	}
	var share models.PersonShare
	if err := db.Where("bill_id = ? AND person_name = ?", bill.ID, "Alex").First(&share).Error; err != nil {
		t.Fatal(err)
	}
	if !share.Paid {
		t.Fatal("rejected edit changed the paid status")
	}
}
