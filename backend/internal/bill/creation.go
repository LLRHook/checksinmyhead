package bill

import (
	"backend/pkg/models"
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql/driver"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"io"
	"math"
	"net"
	"net/http"
	"strings"
)

// These contracts are frozen internal format1. Changing normalization/encoding
// requires a separately reviewed format; existing attempted identities never change.
const creationFingerprintVersion int16 = 1
const creationIdentityVersion uint16 = 1
const creationAccountingVersion uint16 = 1

var (
	ErrInvalidReplayKey = errors.New("invalid creation key")
	ErrReplayConflict   = errors.New("creation conflict")
	ErrReplayVersion    = errors.New("unavailable creation format")
	ErrCreateUncertain  = errors.New("creation outcome unavailable; recover with the same key and content")
)

type CreationKey struct{ digest [32]byte }
type CreateBillCommand struct {
	Content *models.Bill
	Key     *CreationKey
}
type CreateBillResult struct {
	BillID                               uint
	AccessToken, CurrencyCode            string
	USDExchangeRate, USDTotal            float64
	ExchangeRateDate, ExchangeRateSource string
	Replayed                             bool   // internal; never sent on the wire
	OriginalResponse                     []byte // exact persisted response2, never rebuilt on replay
}
type ReplayIdentity struct {
	KeyDigest, Fingerprint [32]byte
	Version                int16
	ClientRefs             []string
}
type CreationInsert struct {
	Bill             *models.Bill
	Replay           *ReplayIdentity
	ParticipantOrder []string
}
type CreationRecord struct {
	Result          CreateBillResult
	Fingerprint     []byte
	Version         *int16
	ResponseVersion *int16
	Response        []byte
}

func parseCreationKey(header http.Header) (*CreationKey, error) {
	present, count, value := false, 0, ""
	for name, values := range header {
		if strings.EqualFold(name, "Idempotency-Key") {
			present = true
			count += len(values)
			if len(values) == 1 {
				value = values[0]
			}
			// Even a second empty map entry cannot turn a present value into absence.
			if len(values) != 1 {
				return nil, ErrInvalidReplayKey
			}
		}
	}
	if !present {
		return nil, nil
	}
	if count != 1 || len(value) != 43 {
		return nil, ErrInvalidReplayKey
	}
	for i := 0; i < len(value); i++ {
		c := value[i]
		if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_') {
			return nil, ErrInvalidReplayKey
		}
	}
	raw, err := base64.RawURLEncoding.Strict().DecodeString(value)
	if err != nil || len(raw) != 32 || base64.RawURLEncoding.EncodeToString(raw) != value {
		return nil, ErrInvalidReplayKey
	}
	return &CreationKey{digest: sha256.Sum256(raw)}, nil
}

func compareCreation(record CreationRecord, identity ReplayIdentity) (CreateBillResult, error) {
	if record.Version == nil || (*record.Version != 1 && *record.Version != 2) || (identity.Version != 1 && identity.Version != 2) || len(record.Fingerprint) != 32 {
		return CreateBillResult{}, ErrReplayVersion
	}
	if *record.Version != identity.Version || subtle.ConstantTimeCompare(record.Fingerprint, identity.Fingerprint[:]) != 1 {
		return CreateBillResult{}, ErrReplayConflict
	}
	if record.Result.BillID == 0 || record.Result.AccessToken == "" {
		return CreateBillResult{}, ErrCreateUncertain
	}
	if *record.Version == 2 {
		if err := validateCreationResponse(record); err != nil {
			return CreateBillResult{}, err
		}
		var original originalCreationResponse
		if err := json.Unmarshal(record.Response, &original); err != nil || len(original.ParticipantMap) != len(identity.ClientRefs) {
			return CreateBillResult{}, ErrCreateUncertain
		}
		for i, p := range original.ParticipantMap {
			if p.ClientRef != identity.ClientRefs[i] {
				return CreateBillResult{}, ErrCreateUncertain
			}
		}
		record.Result.OriginalResponse = append([]byte(nil), record.Response...)
	} else if record.ResponseVersion != nil || record.Response != nil {
		return CreateBillResult{}, ErrCreateUncertain
	}
	record.Result.Replayed = true
	return record.Result, nil
}

func creationStorageError(ctx context.Context, err error) error {
	var network net.Error
	if ctx.Err() != nil || errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) || errors.As(err, &network) || errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) || errors.Is(err, driver.ErrBadConn) {
		return ErrCreateUncertain
	}
	return err
}

func guardCreationContent(b *models.Bill) error {
	if err := guardFreshCreation(b); err != nil {
		return err
	}
	if b.AccessToken != "" || b.USDExchangeRate != 0 || b.USDTotal != 0 || b.ExchangeRateSource != "" || b.ExchangeRateDate != "" || b.ExchangeRate != nil || b.DisplayTotal != nil ||
		b.CreationKeyDigest != nil || b.CreationFingerprint != nil || b.CreationFingerprintVersion != nil || b.DisplayRateDate != nil || b.DisplayRateSource != nil || b.DisplayRateRetrievedAt != nil {
		return ErrInvalidCreation
	}
	return nil
}

func cloneCreation(b *models.Bill) *models.Bill {
	v := *b
	v.Participants = append([]models.Person(nil), b.Participants...)
	v.Items = append([]models.BillItem(nil), b.Items...)
	for i := range v.Items {
		v.Items[i].Assignments = append([]models.ItemAssignment(nil), b.Items[i].Assignments...)
	}
	v.PersonShares = append([]models.PersonShare(nil), b.PersonShares...)
	for i := range v.PersonShares {
		v.PersonShares[i].Items = append([]models.ItemDetail{}, b.PersonShares[i].Items...)
	}
	v.PaymentMethods = append([]models.PaymentMethod(nil), b.PaymentMethods...)
	return &v
}

// creationEncoding is the ordered, length-prefixed input, BEFORE projections are
// derived/replaced. Do not substitute JSON, sort, collapse lines or normalize Unicode.
func creationEncoding(b *models.Bill) []byte {
	out := make([]byte, 0, 256)
	out = append(out, []byte("billington/create\x00")...)
	format, domain := uint16(creationFingerprintVersion), creationIdentityVersion
	if b.InputVersion == 2 {
		format, domain = 2, 2
	}
	out = binary.BigEndian.AppendUint16(out, format)
	out = binary.BigEndian.AppendUint16(out, domain)
	out = binary.BigEndian.AppendUint16(out, creationAccountingVersion)
	str := func(s string) { out = binary.BigEndian.AppendUint32(out, uint32(len(s))); out = append(out, s...) }
	num := func(v float64) {
		if v == 0 {
			v = 0
		}
		out = binary.BigEndian.AppendUint64(out, math.Float64bits(v))
	}
	boolean := func(v bool) {
		if v {
			out = append(out, 1)
		} else {
			out = append(out, 0)
		}
	}
	count := func(n int) { out = binary.BigEndian.AppendUint32(out, uint32(n)) }
	str(b.Name)
	boolean(b.LazyMode)
	num(b.Subtotal)
	num(b.Tax)
	num(b.TipAmount)
	num(b.TipPercentage)
	num(b.Total)
	str(b.CurrencyCode)
	str(b.DisplayCurrency)
	count(len(b.Participants))
	for _, p := range b.Participants {
		if b.InputVersion == 2 && p.ClientRef != nil {
			str(*p.ClientRef)
		}
		str(p.Name)
	}
	count(len(b.Items))
	for _, item := range b.Items {
		str(item.Name)
		num(item.Price)
		count(len(item.Assignments))
		for _, a := range item.Assignments {
			if b.InputVersion == 2 {
				str(a.ParticipantRef)
			} else {
				str(a.PersonName)
			}
			num(a.Percentage)
		}
	}
	count(len(b.PersonShares))
	for _, s := range b.PersonShares {
		if b.InputVersion == 2 {
			str(s.ParticipantRef)
		} else {
			str(s.PersonName)
		}
		count(len(s.Items))
		for _, d := range s.Items {
			str(d.Name)
			num(d.Amount)
			boolean(d.IsShared)
		}
		num(s.Subtotal)
		num(s.TaxShare)
		num(s.TipShare)
		num(s.Total)
	}
	count(len(b.PaymentMethods))
	for _, p := range b.PaymentMethods {
		str(p.Name)
		str(p.Identifier)
	}
	return out
}
func creationFingerprint(b *models.Bill) [32]byte { return sha256.Sum256(creationEncoding(b)) }
