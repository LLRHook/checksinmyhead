package bill

import (
	"backend/internal/currency"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
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
	CreateBill(context.Context, CreateBillCommand) (CreateBillResult, error)
	GetUSDExchangeRate(ctx context.Context, currency string) (models.ExchangeRateQuote, error)
	GetBill(id uint) (bill *models.Bill, err error)
	UpdatePersonSharePaid(context.Context, BillSharePaidCommand) error
	UpdateItemAssignmentsBatch(context.Context, ClaimCommand) error
}

type billService struct {
	repo         BillRepository
	rateProvider ExchangeRateProvider
}

func (b *billService) CreateBill(ctx context.Context, c CreateBillCommand) (CreateBillResult, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	if err := guardCreationContent(c.Content); err != nil {
		return CreateBillResult{}, err
	}
	bill := cloneCreation(c.Content)
	if err := normalizeCreation(bill); err != nil {
		return CreateBillResult{}, err
	}
	var identity *ReplayIdentity
	if c.Key != nil {
		fingerprint := creationFingerprint(bill)
		identity = &ReplayIdentity{KeyDigest: c.Key.digest, Fingerprint: fingerprint, Version: creationFingerprintVersion}
		record, err := b.repo.LookupCreation(ctx, c.Key.digest)
		if err != nil {
			return CreateBillResult{}, creationStorageError(ctx, err)
		}
		if record != nil {
			return compareCreation(*record, *identity)
		}
	}
	if err := deriveCreation(bill); err != nil {
		return CreateBillResult{}, err
	}
	// Quote work stays outside the election transaction and shares one deadline.
	quoteCtx, cancelQuotes := context.WithTimeout(ctx, currency.OperationTimeout)
	defer cancelQuotes()
	quote, err := b.GetUSDExchangeRate(quoteCtx, bill.CurrencyCode)
	if err != nil {
		return CreateBillResult{}, err
	}
	bill.USDExchangeRate, bill.ExchangeRateDate, bill.ExchangeRateSource = quote.Rate, quote.Date, quote.Source
	bill.USDTotal = math.Round(bill.Total*quote.Rate*100) / 100
	if !finite(bill.USDTotal) || bill.USDTotal > float64(math.MaxInt64)/100 {
		return CreateBillResult{}, ErrInvalidCreation
	}
	displayTotal := bill.Total
	bill.ExchangeRate = nil
	source := "same_currency"
	bill.DisplayRateSource = &source
	if bill.CurrencyCode != bill.DisplayCurrency {
		displayQuote := quote
		if bill.DisplayCurrency != "USD" {
			displayQuote, err = b.rateProvider.Latest(quoteCtx, bill.CurrencyCode, bill.DisplayCurrency)
			if err == nil {
				err = currency.ValidateQuote(displayQuote, bill.CurrencyCode, bill.DisplayCurrency, time.Now())
			}
			if err != nil {
				return CreateBillResult{}, fmt.Errorf("%w: %w", ErrDisplayConversionUnavailable, err)
			}
		}
		displayTotal *= displayQuote.Rate
		if !finite(displayTotal) {
			return CreateBillResult{}, ErrDisplayConversionUnavailable
		}
		bill.ExchangeRate = &displayQuote.Rate
		bill.DisplayRateDate, bill.DisplayRateSource, bill.DisplayRateRetrievedAt = &displayQuote.Date, &displayQuote.Source, displayQuote.RetrievedAt
	}
	bill.DisplayTotal = &displayTotal
	bill.AccessToken, err = security.GenerateSecureToken()
	if err != nil {
		return CreateBillResult{}, err
	}
	record, err := b.repo.Create(ctx, CreationInsert{Bill: bill, Replay: identity})
	if err != nil {
		return CreateBillResult{}, creationStorageError(ctx, err)
	}
	return record.Result, nil
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
