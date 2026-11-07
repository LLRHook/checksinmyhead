package tab

import "time"

func quoteReceiptTime() *time.Time { v := time.Now().UTC().Truncate(time.Microsecond); return &v }
