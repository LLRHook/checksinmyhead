package bill

import (
	"backend/pkg/models"
	"gorm.io/gorm"
	"strings"
)

// GraphQuery is shared by standalone and tab read owners. The
// caller supplies one bounded read-only consistent transaction.
func GraphQuery(db *gorm.DB) *gorm.DB {
	return db.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).
		Preload("Items", func(q *gorm.DB) *gorm.DB { return q.Select(models.ItemColumns).Order("id ASC") }).
		Preload("Items.Assignments", func(q *gorm.DB) *gorm.DB { return q.Select(models.AssignmentColumns).Order("id ASC") }).
		Preload("ParticipantRows", func(q *gorm.DB) *gorm.DB { return q.Select(models.ParticipantColumns).Order("ordinal ASC, id ASC") }).
		Preload("PersonShares", func(q *gorm.DB) *gorm.DB { return q.Select(models.ShareColumns).Order("id ASC") })
}
func PopulateLegacyParticipants(b *models.Bill) {
	b.Participants = make([]models.Person, 0, len(b.ParticipantRows))
	for _, p := range b.ParticipantRows {
		b.Participants = append(b.Participants, models.Person{ID: p.PersonID, Name: p.Label})
	}
}

// Only independently valid, known native-USD legacy evidence gets the retained
// in-memory identity fallback. Never hide a foreign/malformed audit or replace
// an explicit frozen zero, and never write this interpretation to the database.
func ReadCurrency(b models.Bill) models.Bill {
	code := strings.ToUpper(strings.TrimSpace(b.CurrencyCode))
	if (code == "" || code == "USD") && b.USDTotal == 0 && b.ExchangeRateSource == "" && b.ExchangeRateDate == "" {
		if cents, err := FrozenUSDTotalCents(b); err == nil {
			b.USDTotal = float64(cents) / 100
			b.CurrencyCode = "USD"
			b.USDExchangeRate = 1
		}
	}
	return b
}

func LegacyBill(b models.Bill) models.Bill {
	b = ReadCurrency(b)
	b.AccessToken = ""
	if b.IdentityVersion != 2 {
		return b
	}
	index, err := ParticipantIndex(b)
	if err != nil {
		return b
	}
	PopulateLegacyParticipants(&b)
	b.Items = append([]models.BillItem(nil), b.Items...)
	for i := range b.Items {
		b.Items[i].Assignments = append([]models.ItemAssignment(nil), b.Items[i].Assignments...)
		for j := range b.Items[i].Assignments {
			a := &b.Items[i].Assignments[j]
			if a.ParticipantID != nil {
				a.PersonName = index[*a.ParticipantID].Label
			}
		}
	}
	b.PersonShares = append([]models.PersonShare(nil), b.PersonShares...)
	for i := range b.PersonShares {
		s := &b.PersonShares[i]
		if s.ParticipantID != nil {
			s.PersonName = index[*s.ParticipantID].Label
		}
	}
	return b
}
