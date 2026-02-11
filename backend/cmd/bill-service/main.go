package main

import (
	"backend/internal/bill"
	"backend/internal/tab"
	"backend/pkg/database"
	"fmt"
	"log"
	"net/http"

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

	tabRepo := tab.NewTabRepository(db)
	tabService := tab.NewTabService(tabRepo)
	tabHandler := tab.NewTabHandler(tabService)

	r := gin.Default()
	r.GET("/health", getHealth)
	r.GET("/api/bills/:id", handler.GetBill)
	r.POST("/api/bills", handler.CreateBill)
	r.POST("/api/tabs", tabHandler.CreateTab)
	r.GET("/api/tabs/:id", tabHandler.GetTab)
	r.POST("/api/tabs/:id/bills", tabHandler.AddBillToTab)
	r.PATCH("/api/tabs/:id", tabHandler.UpdateTab)

	fmt.Println("Bill service starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}

func getHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "bill service - ok"})
}
