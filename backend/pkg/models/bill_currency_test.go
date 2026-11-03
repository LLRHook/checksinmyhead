package models

import "testing"

func TestNormalizeCurrencyPreservesExplicitSavedZero(t *testing.T) {
	// A genuine sub-cent frozen result and an inconsistent historical audit both
	// remain raw evidence on read. Financial mutation separately reviews the latter.
	for _, b := range []Bill{
		{CurrencyCode: "EUR", Total: .001, USDExchangeRate: .27, USDTotal: 0, ExchangeRateSource: "accepted", ExchangeRateDate: "2001-01-01"},
		{CurrencyCode: "EUR", Total: 20, USDExchangeRate: 1.25, USDTotal: 0, ExchangeRateSource: "legacy-audit", ExchangeRateDate: "2001-01-01"},
		{CurrencyCode: "USD", Total: 0, USDExchangeRate: 1, USDTotal: 0, ExchangeRateSource: "native-usd"},
	} {
		b.NormalizeCurrency()
		if b.USDTotal != 0 {
			t.Fatalf("reconstructed saved zero %+v", b)
		}
	}
	legacy := Bill{Total: 20}
	legacy.NormalizeCurrency()
	if legacy.CurrencyCode != "USD" || legacy.USDExchangeRate != 1 || legacy.USDTotal != 20 || legacy.ExchangeRateSource != "native-usd" || legacy.ExchangeRateDate != "" {
		t.Fatalf("legacy defaults %+v", legacy)
	}
}
