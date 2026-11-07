package bill

import (
	"backend/pkg/config"
	"backend/pkg/models"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
)

type ParticipantMapEntry struct {
	ClientRef     string `json:"client_ref"`
	ParticipantID uint   `json:"participant_id"`
}
type originalCreationResponse struct {
	BillID             uint                  `json:"bill_id"`
	AccessToken        string                `json:"access_token"`
	ShareURL           string                `json:"share_url"`
	CurrencyCode       string                `json:"currency_code"`
	USDExchangeRate    float64               `json:"usd_exchange_rate"`
	USDTotal           float64               `json:"usd_total"`
	ExchangeRateDate   string                `json:"exchange_rate_date"`
	ExchangeRateSource string                `json:"exchange_rate_source"`
	ResponseVersion    int16                 `json:"response_version"`
	IdentityVersion    int16                 `json:"identity_version"`
	IdentityRevision   int64                 `json:"identity_revision"`
	ParticipantMap     []ParticipantMapEntry `json:"participant_map"`
}

func creationResponse2(r CreateBillResult, rows []models.BillParticipant) ([]byte, error) {
	v := originalCreationResponse{BillID: r.BillID, AccessToken: r.AccessToken, ShareURL: fmt.Sprintf("%s/b/%d?t=%s", config.AppDomain(), r.BillID, r.AccessToken), CurrencyCode: r.CurrencyCode, USDExchangeRate: r.USDExchangeRate, USDTotal: r.USDTotal, ExchangeRateDate: r.ExchangeRateDate, ExchangeRateSource: r.ExchangeRateSource, ResponseVersion: 2, IdentityVersion: 2, ParticipantMap: []ParticipantMapEntry{}}
	for _, p := range rows {
		if p.ClientRef == nil || p.ID == 0 {
			return nil, ErrCreateUncertain
		}
		v.ParticipantMap = append(v.ParticipantMap, ParticipantMapEntry{*p.ClientRef, p.ID})
	}
	body, err := json.Marshal(v)
	if err != nil || len(body) == 0 || len(body) > 65536 {
		return nil, ErrCreateUncertain
	}
	return body, nil
}
func validateCreationResponse(record CreationRecord) error {
	if record.ResponseVersion == nil || *record.ResponseVersion != 2 || len(record.Response) < 1 || len(record.Response) > 65536 {
		return ErrCreateUncertain
	}
	var v originalCreationResponse
	decoder := json.NewDecoder(bytes.NewReader(record.Response))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&v) != nil || decoder.Decode(new(any)) != io.EOF {
		return ErrCreateUncertain
	}
	canonical, err := json.Marshal(v)
	if err != nil || !bytes.Equal(canonical, record.Response) {
		return ErrCreateUncertain
	}
	r := record.Result
	if v.BillID != r.BillID || v.AccessToken != r.AccessToken || v.CurrencyCode != r.CurrencyCode || v.USDExchangeRate != r.USDExchangeRate || v.USDTotal != r.USDTotal || v.ExchangeRateDate != r.ExchangeRateDate || v.ExchangeRateSource != r.ExchangeRateSource || v.ResponseVersion != 2 || v.IdentityVersion != 2 || v.IdentityRevision != 0 || v.ShareURL == "" || v.ParticipantMap == nil || len(v.ParticipantMap) > 100 {
		return ErrCreateUncertain
	}
	refs := map[string]bool{}
	ids := map[uint]bool{}
	for _, p := range v.ParticipantMap {
		if !validClientRef(p.ClientRef) || refs[p.ClientRef] || p.ParticipantID == 0 || ids[p.ParticipantID] {
			return ErrCreateUncertain
		}
		refs[p.ClientRef] = true
		ids[p.ParticipantID] = true
	}
	return nil
}
