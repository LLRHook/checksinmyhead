package main

import (
	"backend/internal/bill"
	"backend/internal/currency"
	"backend/internal/exchange"
	"backend/internal/healthcheck"
	"backend/internal/readiness"
	"backend/internal/receipt"
	"backend/internal/startup"
	"backend/internal/tab"
	"backend/internal/versionpolicy"
	"backend/migrations"
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	options, err := startup.Parse(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}
	if options.Healthcheck {
		os.Exit(healthcheck.ExitCode("http://127.0.0.1:8080/health", "bill service - ok"))
	}
	if err := receipt.ValidatePolicy(); err != nil {
		log.Fatal(err)
	}

	db, state, err := database.InitDB(context.Background(), options.SchemaMode)
	if err != nil {
		log.Fatal(err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal("database initialization failed")
	}
	defer sqlDB.Close()
	if options.MigrateOnly {
		return
	}
	repo := bill.NewBillRepository(db)
	handler, currencyHandler := newCurrencyHandlers(repo, exchange.NewClient(""))

	tabRepo := tab.NewTabRepository(db)
	tabService := tab.NewTabService(tabRepo)
	tabHandler := tab.NewTabHandler(tabService)

	// Receipt parsing (optional — degrades gracefully if ANTHROPIC_API_KEY is not set)
	var receiptHandler *receipt.Handler
	if receiptService, err := receipt.NewService(); err != nil {
		fmt.Printf("Receipt parsing disabled: %v\n", err)
	} else {
		receiptHandler = receipt.NewHandler(receiptService)
	}

	r, err := newRouter(handler, currencyHandler, tabHandler, receiptHandler, state)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Bill service starting on :8080")
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	err = safehttp.Serve(ctx, ":8080", r)
	if receiptHandler != nil {
		receiptHandler.Close()
	}
	if err != nil {
		log.Print(err)
		os.Exit(1)
	}
}

// newCurrencyHandlers is the production composition path, also exercised over
// HTTP with a synthetic repository and upstream.
func newCurrencyHandlers(repo bill.BillRepository, provider *exchange.Client) (*bill.BillHandler, *currency.Handler) {
	return bill.NewBillHandler(bill.NewBillService(repo, provider)), currency.NewHandler(provider)
}

// newRouter is the router used by the service binary, with injected business handlers.
func newRouter(handler *bill.BillHandler, currencyHandler *currency.Handler, tabHandler *tab.TabHandler, receiptHandler *receipt.Handler, state *migrations.State) (*gin.Engine, error) {
	r, err := safehttp.NewRouter(os.Getenv("TRUSTED_PROXY_CIDRS"))
	if err != nil {
		return nil, err
	}

	// Security headers
	r.Use(func(c *gin.Context) {
		c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Next()
	})

	// CORS — restrict to allowed origins
	origins := []string{"https://billingtonapp.vercel.app"}
	if extra := os.Getenv("CORS_ORIGINS"); extra != "" {
		for _, o := range strings.Split(extra, ",") {
			if trimmed := strings.TrimSpace(o); trimmed != "" {
				origins = append(origins, trimmed)
			}
		}
	}
	r.Use(cors.New(cors.Config{
		AllowOrigins:  origins,
		AllowMethods:  []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:  []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Member-Token", "Idempotency-Key"},
		ExposeHeaders: []string{"Content-Length", "Retry-After"},
	}))
	r.GET("/health", readiness.Handler(state, "bill service - ok"))
	r.GET("/api/app/version-policy", versionpolicy.Handler())
	r.GET("/api/currency/rate", currencyHandler.GetRate)
	r.GET("/api/bills/:id", handler.GetBill)
	r.POST("/api/bills", safehttp.JSONMutation, handler.CreateBill)
	r.GET("/api/exchange-rates/:currency", handler.GetExchangeRate)
	r.PATCH("/api/bills/:id/shares/:shareId", safehttp.JSONMutation, handler.UpdatePersonSharePaid)
	r.PATCH("/api/bills/:id/items/:itemId/assignments", safehttp.JSONMutation, handler.UpdateLazyItemAssignments)
	r.PATCH("/api/bills/:id/assignments", safehttp.JSONMutation, handler.UpdateLazyItemAssignmentsBatch)
	r.POST("/api/tabs", safehttp.JSONMutation, tabHandler.CreateTab)
	r.GET("/api/tabs/:id", tabHandler.GetTab)
	r.POST("/api/tabs/:id/bills", safehttp.JSONMutation, tabHandler.AddBillToTab)
	r.PATCH("/api/tabs/:id/bills/:billId/items/:itemId/assignments", safehttp.JSONMutation, tabHandler.UpdateBillItemAssignments)
	r.PATCH("/api/tabs/:id/bills/:billId/assignments", safehttp.JSONMutation, tabHandler.UpdateBillItemAssignmentsBatch)
	r.PATCH("/api/tabs/:id/bills/:billId/shares/:shareId/paid", safehttp.JSONMutation, tabHandler.UpdateBillPersonSharePaid)
	r.PATCH("/api/tabs/:id", safehttp.JSONMutation, tabHandler.UpdateTab)
	r.POST("/api/tabs/:id/finalize", safehttp.JSONMutation, tabHandler.FinalizeTab)
	r.GET("/api/tabs/:id/settlements", tabHandler.GetSettlements)
	r.PATCH("/api/tabs/:id/settlements/:settlementId", safehttp.JSONMutation, tabHandler.UpdateSettlement)
	r.POST("/api/tabs/:id/join", safehttp.JSONMutation, tabHandler.JoinTab)
	r.DELETE("/api/tabs/:id/members/me", safehttp.JSONMutation, tabHandler.LeaveTab)
	r.GET("/api/tabs/:id/members", tabHandler.GetMembers)

	if receiptHandler != nil {
		r.POST("/api/receipts/parse", receiptHandler.ParseReceipt)
	}

	return r, nil
}
