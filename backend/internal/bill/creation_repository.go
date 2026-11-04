package bill

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"database/sql"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// This private flat projection deliberately has no Bill hooks or associations.
type creationRow struct {
	ID                                   uint
	AccessToken, CurrencyCode            string
	USDExchangeRate, USDTotal            float64
	ExchangeRateDate, ExchangeRateSource string
	CreationFingerprint                  []byte
	CreationFingerprintVersion           *int16
}

const creationColumns = "id,access_token,currency_code,usd_exchange_rate,usd_total,exchange_rate_date,exchange_rate_source,creation_fingerprint,creation_fingerprint_version"

func (r creationRow) record() CreationRecord {
	return CreationRecord{Result: CreateBillResult{BillID: r.ID, AccessToken: r.AccessToken, CurrencyCode: r.CurrencyCode, USDExchangeRate: r.USDExchangeRate, USDTotal: r.USDTotal, ExchangeRateDate: r.ExchangeRateDate, ExchangeRateSource: r.ExchangeRateSource}, Fingerprint: r.CreationFingerprint, Version: r.CreationFingerprintVersion}
}
func lookupCreation(db *gorm.DB, digest [32]byte) (*CreationRecord, error) {
	var row creationRow
	result := db.Table("bills").Select(creationColumns).Where("creation_key_digest = ?", digest[:]).Limit(1).Take(&row)
	if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if result.Error != nil {
		return nil, result.Error
	}
	record := row.record()
	return &record, nil
}
func (b *billRepository) LookupCreation(ctx context.Context, digest [32]byte) (*CreationRecord, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return lookupCreation(b.db.WithContext(ctx), digest)
}

func guardCreationInsert(c CreationInsert) error {
	v := c.Bill
	if err := guardFreshCreation(v); err != nil {
		return err
	}
	if v.CreationKeyDigest != nil || v.CreationFingerprint != nil || v.CreationFingerprintVersion != nil || v.AccessToken == "" || len(v.AccessToken) > 64 || !currency.ReceiptSupported(v.CurrencyCode) || !currency.ValidCode(v.DisplayCurrency) || !money(v.Total) || v.Total < 0 || !finite(v.USDTotal) || v.USDTotal < 0 || !finite(v.USDExchangeRate) || v.USDExchangeRate <= 0 || v.DisplayTotal == nil || !finite(*v.DisplayTotal) || v.DisplayRateSource == nil {
		return ErrInvalidCreation
	}
	if _, err := FrozenUSDTotalCents(*v); err != nil {
		return ErrInvalidCreation
	}
	if c.Replay != nil && c.Replay.Version != creationFingerprintVersion {
		return ErrInvalidCreation
	}
	if v.CurrencyCode == "USD" {
		if v.USDExchangeRate != 1 || v.ExchangeRateDate != "" || v.ExchangeRateSource != "native-usd" {
			return ErrInvalidCreation
		}
	} else {
		if _, err := time.Parse(time.DateOnly, v.ExchangeRateDate); err != nil || v.ExchangeRateSource == "" {
			return ErrInvalidCreation
		}
	}
	if v.CurrencyCode == v.DisplayCurrency {
		if *v.DisplayRateSource != "same_currency" || v.DisplayRateDate != nil || v.DisplayRateRetrievedAt != nil || *v.DisplayTotal != v.Total || v.ExchangeRate != nil {
			return ErrInvalidCreation
		}
	} else {
		if v.ExchangeRate == nil || v.DisplayRateDate == nil {
			return ErrInvalidCreation
		}
		q := models.ExchangeRateQuote{Base: v.CurrencyCode, Quote: v.DisplayCurrency, Rate: *v.ExchangeRate, Date: *v.DisplayRateDate, Source: *v.DisplayRateSource, RetrievedAt: v.DisplayRateRetrievedAt}
		if currency.ValidateQuote(q, v.CurrencyCode, v.DisplayCurrency, time.Now()) != nil {
			return ErrInvalidCreation
		}
	}
	return nil
}

// Create elects one parent, writes only the winner's fresh graph and acknowledges
// the persisted RETURNING identity only AFTER checked commit. Quotes precede Begin.
func (b *billRepository) Create(ctx context.Context, c CreationInsert) (record CreationRecord, runErr error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	if err := guardCreationInsert(c); err != nil {
		return CreationRecord{}, err
	}
	v := cloneCreation(c.Bill)
	if c.Replay != nil {
		v.CreationKeyDigest = append([]byte(nil), c.Replay.KeyDigest[:]...)
		v.CreationFingerprint = append([]byte(nil), c.Replay.Fingerprint[:]...)
		version := c.Replay.Version
		v.CreationFingerprintVersion = &version
	}
	tx := b.db.WithContext(ctx).Session(&gorm.Session{SkipDefaultTransaction: true}).Begin(&sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if tx.Error != nil {
		return CreationRecord{}, tx.Error
	}
	defer func() {
		if err := tx.Rollback().Error; err != nil && !errors.Is(err, sql.ErrTxDone) {
			record = CreationRecord{}
			runErr = ErrCreateUncertain
		}
	}()
	returning := []clause.Column{}
	for _, name := range []string{"id", "access_token", "currency_code", "usd_exchange_rate", "usd_total", "exchange_rate_date", "exchange_rate_source", "creation_fingerprint", "creation_fingerprint_version"} {
		returning = append(returning, clause.Column{Name: name})
	}
	parent := tx.Omit(clause.Associations).Clauses(clause.Returning{Columns: returning})
	if c.Replay != nil {
		parent = parent.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "creation_key_digest"}}, DoNothing: true})
	}
	inserted := parent.Create(v)
	if inserted.Error != nil {
		return CreationRecord{}, inserted.Error
	}
	if inserted.RowsAffected == 0 {
		if c.Replay == nil {
			return CreationRecord{}, ErrCreateUncertain
		}
		// A separate READ COMMITTED statement sees a winner invisible to INSERT's
		// original snapshot after waiting on its unique index. Never query an aborted tx.
		winner, err := lookupCreation(tx, c.Replay.KeyDigest)
		if err != nil {
			return CreationRecord{}, err
		}
		if winner == nil {
			return CreationRecord{}, ErrCreateUncertain
		}
		result, err := compareCreation(*winner, *c.Replay)
		if err != nil {
			return CreationRecord{}, err
		}
		record = *winner
		record.Result = result
	} else if inserted.RowsAffected == 1 {
		if err := insertCreationChildren(tx, v); err != nil {
			return CreationRecord{}, err
		}
		record = CreationRecord{Result: CreateBillResult{BillID: v.ID, AccessToken: v.AccessToken, CurrencyCode: v.CurrencyCode, USDExchangeRate: v.USDExchangeRate, USDTotal: v.USDTotal, ExchangeRateDate: v.ExchangeRateDate, ExchangeRateSource: v.ExchangeRateSource}, Fingerprint: v.CreationFingerprint, Version: v.CreationFingerprintVersion}
	} else {
		return CreationRecord{}, ErrCreateUncertain
	}
	if err := tx.Commit().Error; err != nil {
		return CreationRecord{}, ErrCreateUncertain
	}
	return record, nil
}

type creationParticipant struct {
	BillID   uint
	PersonID uint
}

func insertCreationChildren(tx *gorm.DB, v *models.Bill) error {
	// Explicit batches avoid association callbacks/upserts and per-person lookups.
	if len(v.Participants) > 0 {
		if err := insertCreationBatches(tx, v.Participants); err != nil {
			return err
		}
		joins := make([]creationParticipant, len(v.Participants))
		for i, p := range v.Participants {
			joins[i] = creationParticipant{v.ID, p.ID}
		}
		if err := insertCreationBatches(tx.Table("bill_participants"), joins); err != nil {
			return err
		}
	}
	assignments := []models.ItemAssignment{}
	for i := range v.Items {
		v.Items[i].BillID = v.ID
	}
	if len(v.Items) > 0 {
		if err := insertCreationBatches(tx, v.Items); err != nil {
			return err
		}
		for _, item := range v.Items {
			for _, a := range item.Assignments {
				a.BillItemID = item.ID
				assignments = append(assignments, a)
			}
		}
	}
	if len(assignments) > 0 {
		if err := insertCreationBatches(tx, assignments); err != nil {
			return err
		}
	}
	for i := range v.PersonShares {
		v.PersonShares[i].BillID = v.ID
	}
	if len(v.PersonShares) > 0 {
		if err := insertCreationBatches(tx, v.PersonShares); err != nil {
			return err
		}
	}
	return nil
}

// A trigger/rule can suppress rows without a driver error. Acknowledge only
// complete batches. The owned outer transaction rolls back every earlier batch.
func insertCreationBatches[T any](tx *gorm.DB, values []T) error {
	for start := 0; start < len(values); start += 500 {
		end := min(start+500, len(values))
		batch := values[start:end]
		expected := end - start
		result := tx.Omit(clause.Associations).Create(&batch)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected != int64(expected) {
			return ErrCreateUncertain
		}
	}
	return nil
}
