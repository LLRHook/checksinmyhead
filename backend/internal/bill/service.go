package bill

import (
	"backend/pkg/models"
	"context"
	"errors"
	"fmt"
	"math"
	"regexp"
	"strings"
)

var (
	ErrInvalidCurrency         = errors.New("invalid currency code")
	ErrExchangeRateUnavailable = errors.New("exchange rate unavailable")
)

var currencyCodePattern = regexp.MustCompile(`^[A-Z]{3}$`)

type ExchangeRateProvider interface {
	LatestUSD(ctx context.Context, currency string) (models.ExchangeRateQuote, error)
}

type BillService interface {
	CreateBill(ctx context.Context, bill *models.Bill) error
	GetUSDExchangeRate(ctx context.Context, currency string) (models.ExchangeRateQuote, error)
	GetBill(id uint) (bill *models.Bill, err error)
	UpdatePersonSharePaid(id uint, paid bool) error
}

type billService struct {
	repo         BillRepository
	rateProvider ExchangeRateProvider
}

func (b *billService) CreateBill(ctx context.Context, bill *models.Bill) error {
	quote, err := b.GetUSDExchangeRate(ctx, bill.CurrencyCode)
	if err != nil {
		return err
	}
	bill.CurrencyCode = quote.Base
	bill.USDExchangeRate = quote.Rate
	bill.ExchangeRateDate = quote.Date
	bill.ExchangeRateSource = quote.Source
	bill.USDTotal = math.Round(bill.Total*quote.Rate*100) / 100
	return b.repo.Create(bill)
}

func (b *billService) GetUSDExchangeRate(ctx context.Context, currency string) (models.ExchangeRateQuote, error) {
	currency = strings.ToUpper(strings.TrimSpace(currency))
	if currency == "" {
		currency = "USD"
	}
	if !currencyCodePattern.MatchString(currency) {
		return models.ExchangeRateQuote{}, ErrInvalidCurrency
	}
	if currency == "USD" {
		return models.ExchangeRateQuote{Base: "USD", Quote: "USD", Rate: 1, Source: "native-usd"}, nil
	}
	if b.rateProvider == nil {
		return models.ExchangeRateQuote{}, ErrExchangeRateUnavailable
	}
	quote, err := b.rateProvider.LatestUSD(ctx, currency)
	if err != nil {
		return models.ExchangeRateQuote{}, fmt.Errorf("%w: %v", ErrExchangeRateUnavailable, err)
	}
	if quote.Base != currency || quote.Quote != "USD" || quote.Date == "" || quote.Source == "" || quote.Rate <= 0 || math.IsNaN(quote.Rate) || math.IsInf(quote.Rate, 0) {
		return models.ExchangeRateQuote{}, ErrExchangeRateUnavailable
	}
	return quote, nil
}

func (b *billService) GetBill(id uint) (bill *models.Bill, err error) {
	bill, err = b.repo.GetById(id)
	if err == nil {
		bill.NormalizeCurrency()
	}
	return bill, err
}

func (b *billService) UpdatePersonSharePaid(id uint, paid bool) error {
	return b.repo.UpdatePersonSharePaid(id, paid)
}

func NewBillService(repo BillRepository, providers ...ExchangeRateProvider) BillService {
	var provider ExchangeRateProvider
	if len(providers) > 0 {
		provider = providers[0]
	}
	return &billService{repo: repo, rateProvider: provider}
}
