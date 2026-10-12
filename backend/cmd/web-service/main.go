package main

import (
	"backend/internal/bill"
	"backend/internal/web"
	"backend/pkg/database"
	"backend/pkg/safehttp"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func main() {
	db, err := database.InitDB()
	if err != nil {
		log.Fatal(err)
	}
	repo := bill.NewBillRepository(db)
	service := bill.NewBillService(repo)
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
	r.GET("/health", getHealth)
	r.GET("/b/:id", handler.CreateHTML)

	fmt.Println("Web Service starting on :8081")
	log.Fatal(http.ListenAndServe(":8081", r))
}

func getHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "web service - ok",
		"commit": os.Getenv("RENDER_GIT_COMMIT"),
	})
}
