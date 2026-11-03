package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/healthcheck"
	"backend/internal/readiness"
	"backend/internal/startup"
	"backend/internal/web"
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"context"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	options, err := startup.Parse(os.Args[1:])
	if err != nil {
		log.Fatal(err)
	}
	if options.Healthcheck {
		os.Exit(healthcheck.ExitCode("http://127.0.0.1:8081/health", "web service - ok"))
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
	service := bill.NewBillService(repo, exchange.NewClient(""))
	handler := web.NewWebpageHandler(service)

	r := gin.New()
	r.Use(safehttp.RequestLogger(), gin.Recovery())
	r.Use(func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Next()
	})
	r.LoadHTMLGlob("internal/web/templates/*")
	r.GET("/health", readiness.Handler(state, "web service - ok"))
	r.GET("/b/:id", handler.CreateHTML)

	fmt.Println("Web Service starting on :8081")
	log.Fatal(http.ListenAndServe(":8081", r))
}
