package main

import (
	"backend/internal/bill"
	"backend/internal/image"
	"backend/internal/receipt"
	"backend/internal/tab"
	"backend/pkg/database"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var db *gorm.DB

func main() {
	var err error
	db, err = database.InitDB()
	if err != nil {
		log.Fatal(err)
	}
	repo := bill.NewBillRepository(db)
	service := bill.NewBillService(repo)
	handler := bill.NewBillHandler(service)

	uploadDir := os.Getenv("UPLOAD_DIR")
	if uploadDir == "" {
		uploadDir = "./uploads"
	}

	imgRepo := image.NewImageRepository(db)
	imgService := image.NewImageService(imgRepo)

	tabRepo := tab.NewTabRepository(db)
	tabService := tab.NewTabService(tabRepo, imgService)
	tabHandler := tab.NewTabHandler(tabService)

	imgHandler := image.NewImageHandler(imgService, tabService, uploadDir)

	// Receipt parsing (optional — degrades gracefully if ANTHROPIC_API_KEY is not set)
	var receiptHandler *receipt.Handler
	if receiptService, err := receipt.NewService(); err != nil {
		fmt.Printf("Receipt parsing disabled: %v\n", err)
	} else {
		receiptHandler = receipt.NewHandler(receiptService)
	}

	r := gin.Default()

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
		AllowOrigins: origins,
		AllowMethods: []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders: []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Member-Token"},
		ExposeHeaders: []string{"Content-Length"},
	}))
	r.GET("/health", getHealth)
	r.GET("/api/bills/:id", handler.GetBill)
	r.POST("/api/bills", handler.CreateBill)
	r.PATCH("/api/bills/:id/shares/:shareId", handler.UpdatePersonSharePaid)
	r.POST("/api/tabs", tabHandler.CreateTab)
	r.GET("/api/tabs/:id", tabHandler.GetTab)
	r.POST("/api/tabs/:id/bills", tabHandler.AddBillToTab)
	r.PATCH("/api/tabs/:id", tabHandler.UpdateTab)
	r.POST("/api/tabs/:id/finalize", tabHandler.FinalizeTab)
	r.GET("/api/tabs/:id/settlements", tabHandler.GetSettlements)
	r.PATCH("/api/tabs/:id/settlements/:settlementId", tabHandler.UpdateSettlement)
	r.POST("/api/tabs/:id/join", tabHandler.JoinTab)
	r.GET("/api/tabs/:id/members", tabHandler.GetMembers)

	if receiptHandler != nil {
		r.POST("/api/receipts/parse", receiptHandler.ParseReceipt)
	}

	r.POST("/api/tabs/:id/images", imgHandler.UploadImage)
	r.GET("/api/tabs/:id/images", imgHandler.ListImages)
	r.PATCH("/api/tabs/:id/images/:imageId", imgHandler.UpdateImage)
	r.DELETE("/api/tabs/:id/images/:imageId", imgHandler.DeleteImage)

	r.Static("/uploads", uploadDir)

	fmt.Println("Bill service starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}

func getHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "bill service - ok"})
}
