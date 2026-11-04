package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/healthcheck"
	"backend/internal/readiness"
	"backend/internal/startup"
	"backend/internal/web"
	"backend/migrations"
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

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

	r, err := newRouter(handler, state)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Web Service starting on :8081")
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := safehttp.Serve(ctx, ":8081", r); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}

// newRouter is shared by the retained HTML binary and its transport tests.
func newRouter(handler *web.WebpageHandler, state *migrations.State) (*gin.Engine, error) {
	r, err := safehttp.NewRouter(os.Getenv("TRUSTED_PROXY_CIDRS"))
	if err != nil {
		return nil, err
	}
	r.Use(func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Next()
	})
	r.LoadHTMLGlob("internal/web/templates/*")
	r.GET("/health", readiness.Handler(state, "web service - ok"))
	r.GET("/b/:id", handler.CreateHTML)

	return r, nil
}
