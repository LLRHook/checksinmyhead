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
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

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

	r := gin.New()
	r.Use(safehttp.RequestLogger(), gin.Recovery())

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
		AllowHeaders:  []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Member-Token"},
		ExposeHeaders: []string{"Content-Length"},
	}))
	r.GET("/health", readiness.Handler(state, "bill service - ok"))
	r.GET("/api/app/version-policy", versionpolicy.Handler())
	r.GET("/api/currency/rate", currencyHandler.GetRate)
	r.GET("/api/bills/:id", handler.GetBill)
	r.POST("/api/bills", handler.CreateBill)
	r.GET("/api/exchange-rates/:currency", handler.GetExchangeRate)
	r.PATCH("/api/bills/:id/shares/:shareId", handler.UpdatePersonSharePaid)
	r.PATCH("/api/bills/:id/items/:itemId/assignments", handler.UpdateLazyItemAssignments)
	r.PATCH("/api/bills/:id/assignments", handler.UpdateLazyItemAssignmentsBatch)
	r.POST("/api/tabs", tabHandler.CreateTab)
	r.GET("/api/tabs/:id", tabHandler.GetTab)
	r.POST("/api/tabs/:id/bills", tabHandler.AddBillToTab)
	r.PATCH("/api/tabs/:id/bills/:billId/items/:itemId/assignments", tabHandler.UpdateBillItemAssignments)
	r.PATCH("/api/tabs/:id/bills/:billId/assignments", tabHandler.UpdateBillItemAssignmentsBatch)
	r.PATCH("/api/tabs/:id/bills/:billId/shares/:shareId/paid", tabHandler.UpdateBillPersonSharePaid)
	r.PATCH("/api/tabs/:id", tabHandler.UpdateTab)
	r.POST("/api/tabs/:id/finalize", tabHandler.FinalizeTab)
	r.GET("/api/tabs/:id/settlements", tabHandler.GetSettlements)
	r.PATCH("/api/tabs/:id/settlements/:settlementId", tabHandler.UpdateSettlement)
	r.POST("/api/tabs/:id/join", tabHandler.JoinTab)
	r.DELETE("/api/tabs/:id/members/me", tabHandler.LeaveTab)
	r.GET("/api/tabs/:id/members", tabHandler.GetMembers)

	if receiptHandler != nil {
		r.POST("/api/receipts/parse", receiptHandler.ParseReceipt)
	}

	fmt.Println("Bill service starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}

// newCurrencyHandlers is the production composition path, also exercised over
// HTTP with a synthetic repository and upstream.
func newCurrencyHandlers(repo bill.BillRepository, provider *exchange.Client) (*bill.BillHandler, *currency.Handler) {
	return bill.NewBillHandler(bill.NewBillService(repo, provider)), currency.NewHandler(provider)
}
