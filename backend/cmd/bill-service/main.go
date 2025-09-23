package main

import (
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
	r := gin.Default()

	r.GET("/health", getHealth)
	r.GET("/api/bills/:id", getBillById)
	r.POST("/api/bills", postBill)

	fmt.Println("Bill service starting on :8080")
	log.Fatal(http.ListenAndServe(":8080", r))
}

func getHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func postBill(c *gin.Context) {
	//db.Create()
	c.JSON(http.StatusCreated, gin.H{"message": "Bill created", "id": "test-123"})
}

func getBillById(c *gin.Context) {
	//id = c.Param("id")
	c.JSON(http.StatusNotFound, gin.H{"message": "couldn't find bill"})
}
