//go:build integration

package bill

import (
	"backend/pkg/models"
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"gorm.io/gorm"
)

func referenceReplayInsert(t *testing.T, token string) CreationInsert {
	t.Helper()
	ref := "a"
	v := &models.Bill{Name: "Original reference", InputVersion: 2, Subtotal: 10, Total: 10, CurrencyCode: "USD", Participants: []models.Person{{Name: "Alex", ClientRef: &ref}}, Items: []models.BillItem{{Name: "First", Price: 6, Assignments: []models.ItemAssignment{{ParticipantRef: ref, Percentage: 100}}}, {Name: "Second", Price: 4, Assignments: []models.ItemAssignment{{ParticipantRef: ref, Percentage: 100}}}}}
	if err := normalizeCreation(v); err != nil {
		t.Fatal(err)
	}
	fingerprint := creationFingerprint(v)
	order := documentParticipantOrder(v)
	if err := deriveCreation(v); err != nil {
		t.Fatal(err)
	}
	v.USDExchangeRate, v.USDTotal, v.ExchangeRateSource, v.AccessToken = 1, 10, "native-usd", token
	display, source := 10.0, "same_currency"
	v.DisplayTotal, v.DisplayRateSource = &display, &source
	return CreationInsert{Bill: v, Replay: &ReplayIdentity{KeyDigest: [32]byte{27}, Fingerprint: fingerprint, Version: 2, ClientRefs: []string{ref}}, ParticipantOrder: order}
}

func TestPostgresIdentity0003Response2WinnerAndCommitLoss(t *testing.T) {
	t.Run("real_winner_waiter_exact_original", func(t *testing.T) {
		db, g := replayPG(t)
		entered, release := make(chan struct{}), make(chan struct{})
		var releaseOnce sync.Once
		t.Cleanup(func() { releaseOnce.Do(func() { close(release) }) })
		var held atomic.Bool
		if err := g.Callback().Create().After("gorm:create").Register("test:hold_reference_winner", func(tx *gorm.DB) {
			if tx.Statement.Table == "bills" && tx.RowsAffected == 1 && held.CompareAndSwap(false, true) {
				close(entered)
				<-release
			}
		}); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { g.Callback().Create().Remove("test:hold_reference_winner") })
		winnerCh, waiterCh := make(chan error, 1), make(chan error, 1)
		var winner, waiter CreationRecord
		winnerInput, waiterInput := referenceReplayInsert(t, "winner-token"), referenceReplayInsert(t, "waiter-token")
		go func() {
			var err error
			winner, err = (&billRepository{db: g}).Create(context.Background(), winnerInput)
			winnerCh <- err
		}()
		select {
		case <-entered:
		case <-time.After(12 * time.Second):
			t.Fatal("winner did not reach real parent insert")
		}
		go func() {
			var err error
			waiter, err = (&billRepository{db: g}).Create(context.Background(), waiterInput)
			waiterCh <- err
		}()
		replayWait(t, db, "transactionid")
		releaseOnce.Do(func() { close(release) })
		if err := replayReceive(t, winnerCh); err != nil {
			t.Fatal(err)
		}
		if err := replayReceive(t, waiterCh); err != nil {
			t.Fatal(err)
		}
		if len(winner.Response) == 0 || string(winner.Response) != string(waiter.Response) || string(winner.Result.OriginalResponse) != string(waiter.Result.OriginalResponse) || waiter.Result.AccessToken != "winner-token" || !waiter.Result.Replayed {
			t.Fatal("waiter did not return the winner's durable response")
		}
		replayGraph(t, db, 1)
	})
	for _, after := range []bool{false, true} {
		t.Run(map[bool]string{false: "before_commit_rollback", true: "after_commit_durable"}[after], func(t *testing.T) {
			db, ordinary := replayPG(t)
			proxied, cut := commitLossProxy(t, db, after)
			result, err := (&billRepository{db: proxied}).Create(context.Background(), referenceReplayInsert(t, "attempt-token"))
			if !errors.Is(err, ErrCreateUncertain) || !cut.Load() || result.Result.BillID != 0 || len(result.Result.OriginalResponse) != 0 {
				t.Fatal("uncertain response2 outcome acknowledged")
			}
			want := 0
			if after {
				want = 1
			}
			replayGraph(t, db, want)
			var durable []byte
			if after {
				if err := db.QueryRow("SELECT creation_response FROM bills").Scan(&durable); err != nil {
					t.Fatal(err)
				}
			}
			recovered, err := (&billRepository{db: ordinary}).Create(context.Background(), referenceReplayInsert(t, "recovered-token"))
			if err != nil {
				t.Fatal(err)
			}
			if after && (string(recovered.Result.OriginalResponse) != string(durable) || recovered.Result.AccessToken != "attempt-token" || !recovered.Result.Replayed) {
				t.Fatal("lost commit recovery rebuilt original response")
			}
			if !after && (recovered.Result.AccessToken != "recovered-token" || recovered.Result.Replayed || len(recovered.Result.OriginalResponse) == 0) {
				t.Fatal("rolled-back attempt prevented healthy same-key response2")
			}
			replayGraph(t, db, 1)
		})
	}
}
