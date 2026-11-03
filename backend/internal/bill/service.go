package bill

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"errors"
	"fmt"
	"math"
	"time"
)

var (
	ErrDisplayConversionUnavailable = errors.New("display conversion unavailable")
	ErrInvalidCurrency              = errors.New("invalid currency code")
	ErrExchangeRateUnavailable      = errors.New("exchange rate unavailable")
	ErrAssignmentConflict           = errors.New("item changed; refresh and try again")
	ErrItemAlreadyPaid              = errors.New("item belongs to a paid share")
	ErrPersonShareNotFound          = errors.New("person share not found")
)

// ExchangeRateProvider is shared by frozen valuation, preview and display.
type ExchangeRateProvider = currency.Provider

type BillService interface {
	CreateBill(ctx context.Context, bill *models.Bill) error
	GetUSDExchangeRate(ctx context.Context, currency string) (models.ExchangeRateQuote, error)
	GetBill(id uint) (bill *models.Bill, err error)
	UpdatePersonSharePaid(context.Context, BillSharePaidCommand) error
	UpdateItemAssignmentsBatch(context.Context, ClaimCommand) error
}

type billService struct {
	repo         BillRepository
	rateProvider ExchangeRateProvider
}

func (b *billService) CreateBill(ctx context.Context, bill *models.Bill) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	if err := prepareCreation(bill); err != nil {
		return err
	}
	// All distinct pairs in a creation share one deadline. The frozen quote also
	// supplies a requested USD display; this is operation-local reuse, not a cache.
	quoteCtx, cancelQuotes := context.WithTimeout(ctx, currency.OperationTimeout)
	defer cancelQuotes()
	quote, err := b.GetUSDExchangeRate(quoteCtx, bill.CurrencyCode)
	if err != nil {
		return err
	}
	bill.CurrencyCode = quote.Base
	bill.USDExchangeRate = quote.Rate
	bill.ExchangeRateDate = quote.Date
	bill.ExchangeRateSource = quote.Source
	bill.USDTotal = math.Round(bill.Total*quote.Rate*100) / 100
	if !finite(bill.USDTotal) || bill.USDTotal > float64(math.MaxInt64)/100 {
		return ErrInvalidCreation
	}
	displayTotal := bill.Total
	bill.ExchangeRate = nil
	if bill.CurrencyCode != bill.DisplayCurrency {
		displayQuote := quote
		if bill.DisplayCurrency != "USD" {
			displayQuote, err = b.rateProvider.Latest(quoteCtx, bill.CurrencyCode, bill.DisplayCurrency)
			if err == nil {
				err = currency.ValidateQuote(displayQuote, bill.CurrencyCode, bill.DisplayCurrency, time.Now())
			}
			if err != nil {
				return fmt.Errorf("%w: %w", ErrDisplayConversionUnavailable, err)
			}
		}
		displayTotal *= displayQuote.Rate
		if !finite(displayTotal) {
			return ErrDisplayConversionUnavailable
		}
		bill.ExchangeRate = &displayQuote.Rate
	}
	// exchange_rate_date/source belong exclusively to frozen USD. Distinct
	// persisted display provenance awaits approved migration 0002.
	bill.DisplayTotal = &displayTotal
	return b.repo.Create(ctx, bill)
}

func (b *billService) GetUSDExchangeRate(ctx context.Context, currencyCode string) (models.ExchangeRateQuote, error) {
	currencyCode = currency.Normalize(currencyCode)
	if currencyCode == "" {
		currencyCode = "USD"
	}
	if !currency.ReceiptSupported(currencyCode) {
		return models.ExchangeRateQuote{}, ErrInvalidCurrency
	}
	if currencyCode == "USD" {
		return models.ExchangeRateQuote{Base: "USD", Quote: "USD", Rate: 1, Source: "native-usd"}, nil
	}
	ctx, cancel := context.WithTimeout(ctx, currency.OperationTimeout)
	defer cancel()
	quote, err := b.rateProvider.Latest(ctx, currencyCode, "USD")
	if err == nil {
		err = currency.ValidateQuote(quote, currencyCode, "USD", time.Now())
	}
	if err != nil {
		return models.ExchangeRateQuote{}, fmt.Errorf("%w: %w", ErrExchangeRateUnavailable, err)
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

func (b *billService) UpdatePersonSharePaid(ctx context.Context, c BillSharePaidCommand) error {
	return b.repo.UpdatePersonSharePaid(ctx, c)
}
func (b *billService) UpdateItemAssignmentsBatch(ctx context.Context, c ClaimCommand) error {
	return b.repo.UpdateItemAssignmentsBatch(ctx, c)
}

func NewBillService(repo BillRepository, provider ExchangeRateProvider) BillService {
	if provider == nil {
		panic("currency provider is required")
	}
	return &billService{repo: repo, rateProvider: provider}
}
