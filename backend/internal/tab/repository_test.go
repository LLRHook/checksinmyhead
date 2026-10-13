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

func TestUpdateBillItemAssignmentsBatchRollsBackEveryItemOnFailure(t *testing.T) {
	db := newTabRepositoryTestDB(t)
	tab := models.Tab{Name: "Trip"}
	if err := db.Create(&tab).Error; err != nil {
		t.Fatal(err)
	}
	bill := models.Bill{TabID: &tab.ID, Name: "Receipt", Subtotal: 10, Total: 10, Date: time.Now()}
	if err := db.Create(&bill).Error; err != nil {
		t.Fatal(err)
	}
	first := models.BillItem{BillID: bill.ID, Name: "First", Price: 5, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}
	second := models.BillItem{BillID: bill.ID, Name: "Second", Price: 5, Assignments: []models.ItemAssignment{{PersonName: "Paid person", Percentage: 100}}}
	if err := db.Create(&first).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&second).Error; err != nil {
		t.Fatal(err)
	}
	if err := db.Create(&models.PersonShare{BillID: bill.ID, PersonName: "Paid person", Subtotal: 5, Total: 5, Paid: true}).Error; err != nil {
		t.Fatal(err)
	}

	err := (&tabRepository{db: db}).UpdateBillItemAssignmentsBatch(tab.ID, bill.ID, []BillItemAssignmentsUpdate{
		{ItemID: first.ID, Assignments: []models.ItemAssignment{{PersonName: "Sam", Percentage: 100}}},
		{ItemID: second.ID, Assignments: []models.ItemAssignment{}},
	})
	if !errors.Is(err, ErrItemAlreadyPaid) {
		t.Fatalf("expected paid share rejection, got %v", err)
	}
	var firstAssignments []models.ItemAssignment
	if err := db.Where("bill_item_id = ?", first.ID).Find(&firstAssignments).Error; err != nil {
		t.Fatal(err)
	}
	if len(firstAssignments) != 1 || firstAssignments[0].PersonName != "Alex" {
		t.Fatalf("first item changed despite batch failure: %#v", firstAssignments)
	}
	var secondAssignments []models.ItemAssignment
	if err := db.Where("bill_item_id = ?", second.ID).Find(&secondAssignments).Error; err != nil {
		t.Fatal(err)
	}
	if len(secondAssignments) != 1 || secondAssignments[0].PersonName != "Paid person" {
		t.Fatalf("paid item changed despite batch failure: %#v", secondAssignments)
	}
}
