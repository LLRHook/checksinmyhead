package bill

import (
	"backend/pkg/models"
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"reflect"
	"testing"
	"time"
)

type replayCountingRepo struct {
	BillRepository
	lookups, creates int
}

func (r *replayCountingRepo) LookupCreation(ctx context.Context, d [32]byte) (*CreationRecord, error) {
	r.lookups++
	return r.BillRepository.LookupCreation(ctx, d)
}
func (r *replayCountingRepo) Create(ctx context.Context, c CreationInsert) (CreationRecord, error) {
	r.creates++
	return r.BillRepository.Create(ctx, c)
}
func TestReplayServiceValidatesBeforeLookupAndSkipsProviderAndDerivation(t *testing.T) {
	memory := newMockRepo()
	repo := &replayCountingRepo{BillRepository: memory}
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{Base: "EUR", Quote: "USD", Rate: 1.25, Date: time.Now().UTC().Format(time.DateOnly), Source: "synthetic", RetrievedAt: quoteReceiptTime()}}
	service := NewBillService(repo, provider)
	key, err := parseCreationKey(http.Header{"Idempotency-Key": {base64.RawURLEncoding.EncodeToString(make([]byte, 32))}})
	if err != nil {
		t.Fatal(err)
	}
	content := &models.Bill{Name: "Receipt", CurrencyCode: "EUR", DisplayCurrency: "USD", Subtotal: 10, Total: 10, Items: []models.BillItem{{Name: "Repeated", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}, PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 10, Total: 10, Items: []models.ItemDetail{{Name: "Repeated", Amount: 10}}}}}
	before := cloneCreation(content)
	first, err := service.CreateBill(context.Background(), CreateBillCommand{Content: content, Key: key})
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(before, content) {
		t.Fatal("attempted snapshot mutated")
	}
	provider.err = errors.New("provider disabled for recovery")
	replay, err := service.CreateBill(context.Background(), CreateBillCommand{Content: content, Key: key})
	if err != nil || replay.BillID != first.BillID || replay.AccessToken != first.AccessToken || !replay.Replayed || repo.creates != 1 || provider.calls != 1 {
		t.Fatal("established replay ran fresh creation")
	}
	for _, modify := range []func(*models.Bill){
		func(v *models.Bill) { v.ID = 1 }, func(v *models.Bill) { v.AccessToken = "injected" }, func(v *models.Bill) { v.USDTotal = 1 }, func(v *models.Bill) { v.USDExchangeRate = 1 }, func(v *models.Bill) { v.ExchangeRateDate = "2026-11-04" }, func(v *models.Bill) { v.ExchangeRateSource = "injected" }, func(v *models.Bill) { s := "same_currency"; v.DisplayRateSource = &s }, func(v *models.Bill) { v.CreationKeyDigest = []byte{} }, func(v *models.Bill) { v.CreationFingerprint = []byte{} }, func(v *models.Bill) { x := int16(1); v.CreationFingerprintVersion = &x }, func(v *models.Bill) { v.Items[0].Assignments[0].BillItemID = 1 }, func(v *models.Bill) { v.PersonShares[0].Paid = true },
	} {
		v := cloneCreation(content)
		modify(v)
		n := repo.lookups
		if result, err := service.CreateBill(context.Background(), CreateBillCommand{Content: v, Key: key}); !errors.Is(err, ErrInvalidCreation) || repo.lookups != n || result.AccessToken != "" {
			t.Fatal("privileged replay reached storage or disclosed identity")
		}
	}
	changed := cloneCreation(content)
	changed.Total = 12
	changed.Tax = 2
	if result, err := service.CreateBill(context.Background(), CreateBillCommand{Content: changed, Key: key}); !errors.Is(err, ErrReplayConflict) || result.AccessToken != "" || provider.calls != 1 {
		t.Fatal("changed admissible content conflict")
	}
}
