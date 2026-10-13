package bill

import (
	"backend/pkg/models"
	"errors"
	"testing"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func newBillRepositoryTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.Bill{}, &models.BillItem{}, &models.ItemAssignment{}, &models.PersonShare{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func TestPreservesPaidAssignmentsRejectsPercentageChanges(t *testing.T) {
	paid := map[string]bool{"alex": true}
	current := []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}}

	if !PreservesPaidAssignments(current, []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}}, paid) {
		t.Fatal("unchanged paid assignment should be allowed")
	}
	if PreservesPaidAssignments(current, []models.ItemAssignment{{PersonName: "Alex", Percentage: 50.009}}, paid) {
		t.Fatal("paid assignment percentage change should be rejected")
	}
}

func TestUpdateItemAssignmentsBatchRejectsAddingToPaidShare(t *testing.T) {
	db := newBillRepositoryTestDB(t)
	bill := models.Bill{LazyMode: true, Name: "Dinner", Subtotal: 12, Total: 12, Date: time.Now()}
	if err := db.Create(&bill).Error; err != nil {
		t.Fatal(err)
	}
	item := models.BillItem{BillID: bill.ID, Name: "Beer", Price: 6}
	if err := db.Create(&item).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&models.PersonShare{BillID: bill.ID, PersonName: "Alex", Subtotal: 6, Total: 6, Paid: true}).Error; err != nil {
		t.Fatal(err)
	}

	repo := NewBillRepository(db)
	err := repo.UpdateItemAssignmentsBatch(bill.ID, []ItemAssignmentsUpdate{{
		ItemID:      item.ID,
		Assignments: []models.ItemAssignment{{PersonName: "alex", Percentage: 100}},
	}})
	if !errors.Is(err, ErrItemAlreadyPaid) {
		t.Fatalf("expected paid share assignment rejection, got %v", err)
	}

	var assignmentCount int64
	if err := db.Model(&models.ItemAssignment{}).Where("bill_item_id = ?", item.ID).Count(&assignmentCount).Error; err != nil {
		t.Fatal(err)
	}
	if assignmentCount != 0 {
		t.Fatalf("rejected assignment persisted %d row(s)", assignmentCount)
	}
}

func TestUpdatePersonSharePaidUpdatesRefreshedShareByBillAndName(t *testing.T) {
	db := newBillRepositoryTestDB(t)
	bill := models.Bill{
		LazyMode: true, Name: "Dinner", Subtotal: 12, Total: 12, Date: time.Now(),
		Items: []models.BillItem{
			{Name: "Wine", Price: 6, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
			{Name: "Beer", Price: 6, Assignments: []models.ItemAssignment{{PersonName: "Sam", Percentage: 100}}},
		},
		PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 6, Total: 6}},
	}
	if err := db.Create(&bill).Error; err != nil {
		t.Fatal(err)
	}
	var oldShare models.PersonShare
	if err := db.Where("bill_id = ? AND person_name = ?", bill.ID, "Alex").First(&oldShare).Error; err != nil {
		t.Fatal(err)
	}
	var alexItem models.BillItem
	if err := db.Preload("Assignments").Where("bill_id = ? AND name = ?", bill.ID, "Wine").First(&alexItem).Error; err != nil {
		t.Fatal(err)
	}

	repo := NewBillRepository(db)
	if err := repo.UpdatePersonSharePaid(bill.ID, "Alex", false); err != nil {
		t.Fatalf("idempotent unpaid update should succeed: %v", err)
	}
	if err := repo.UpdateItemAssignmentsBatch(bill.ID, []ItemAssignmentsUpdate{{
		ItemID:      alexItem.ID,
		Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}},
	}}); err != nil {
		t.Fatal(err)
	}
	if err := repo.UpdatePersonSharePaid(bill.ID, "aLeX", true); err != nil {
		t.Fatalf("payment update should find the recreated share by name: %v", err)
	}

	var refreshed models.PersonShare
	if err := db.Where("bill_id = ? AND LOWER(person_name) = ?", bill.ID, "alex").First(&refreshed).Error; err != nil {
		t.Fatal(err)
	}
	if refreshed.ID == oldShare.ID {
		t.Fatalf("expected assignment save to recreate share ID %d", oldShare.ID)
	}
	if !refreshed.Paid {
		t.Fatal("payment update did not mark the refreshed share paid")
	}
}
