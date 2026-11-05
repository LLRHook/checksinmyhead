//go:build integration

package tab

import (
	"backend/internal/testidentity"
	"backend/pkg/models"
	"gorm.io/gorm"
	"testing"
)

// Explicit new-snapshot fixture. The historical seedLifecycle remains graph1
// for legacy containment; tests opt into this modern premise at their call site.
func seedReferenceLifecycle(t *testing.T, db *gorm.DB) (models.Tab, models.Bill, TabAccess) {
	t.Helper()
	dst, b, a := seedLifecycle(t, db)
	testidentity.Ready(t, db, &b, "Sam")
	return dst, b, a
}
