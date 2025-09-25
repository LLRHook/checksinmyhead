// import (
// 	"fmt"
// 	"net/http"
// 	"time"

// 	"github.com/gin-gonic/gin"
// 	"github.com/google/uuid"
// )

// type Handler struct {
// 	service *Service
// }

// type CreateBillRequest struct {
// 	Items        []Item        `json:"items"`
// 	Participants []Participant `json:"participants"`
// }

// type CreateBillResponse struct {
// 	BillID      string `json:"billId"`
// 	AccessToken string `json:"accessToken"`
// 	ShareURL    string `json:"shareUrl"`
// }

// func (h *Handler) CreateBill(c *gin.Context) {
// 	var req CreateBillRequest
// 	if err := c.ShouldBindJSON(&req); err != nil {
// 		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
// 		return
// 	}

// 	billID := uuid.New().String()
// 	accessToken := generateSecureToken()

// 	bill := Bill{
// 		ID:           billID,
// 		AccessToken:  accessToken,
// 		Items:        req.Items,
// 		Participants: req.Participants,
// 		Status:       "active",
// 		ExpiresAt:    time.Now().Add(30 * 24 * time.Hour),
// 	}

// 	if err := h.service.CreateBill(bill); err != nil {
// 		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
// 		return
// 	}

//		c.JSON(http.StatusCreated, CreateBillResponse{
//			BillID:      billID,
//			AccessToken: accessToken,
//			ShareURL:    fmt.Sprintf("https://Billington.app/b/%s?t=%s", billID, accessToken),
//		})
//	}
package bill
