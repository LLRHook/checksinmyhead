# Checkmate Sample Data Format

This document outlines the data format for bill splitting in the Checkmate app, with examples of input parameters and expected output formats.

## Input Parameters

### Participants
```
Joe
Bob
Trudy
Bill
```

### Bill Details
| Item | Value |
|------|-------|
| Subtotal | $65.00 |
| Tax | $14.00 |
| Tip | 25% |
| **Total** | **$95.25** |

### Items
| Item | Price |
|------|-------|
| Salad | $12.00 |
| Beer | $13.00 |
| Nachos | $20.00 |
| Burger | $15.00 |
| Mac & Cheese | $5.00 |
| **Total** | **$65.00** |

### Item Assignments
| Item | Assigned To |
|------|-------------|
| Salad | Trudy |
| Beer | Joe |
| Nachos | Even split with everyone |
| Burger | Bob |
| Mac & Cheese | Bill |

### Sharing Options
| Option | Status |
|--------|--------|
| List all items | OFF |
| Hide Breakdown | ON |
| Show each person's items | ON |

## Output Format

```
BILL SUMMARY
Total: $95.25
───────────────
INDIVIDUAL SHARES:

• Bob: $29.31
  - Nachos: $5.00 (shared)
  - Burger: $15.00

• Joe: $26.38
  - Beer: $13.00
  - Nachos: $5.00 (shared)

• Trudy: $24.91
  - Salad: $12.00
  - Nachos: $5.00 (shared)

• Bill: $14.65
  - Nachos: $5.00 (shared)
  - Mac & Cheese: $5.00
───────────────
PAYMENT DETAILS:
Venmo: joebob1
Zelle: 1234567890
───────────────
Split with CheckMate
```

## Calculation Logic

1. **Base Item Cost**: Each person is assigned their item costs
2. **Shared Items**: Items marked as "shared" are split evenly among participants
3. **Tax & Tip**: Allocated proportionally based on each person's item totals
4. **Final Amount**: Base item cost + share of shared items + proportional tax & tip

## Calculation Proof

| Person | Base Items | Shared Items | Subtotal | Tax | Tip | Total |
|--------|------------|--------------|----------|-----|-----|-------|
| Bob | $15.00 | $5.00 | $20.00 | $4.31 | $5.00 | $29.31 |
| Joe | $13.00 | $5.00 | $18.00 | $3.88 | $4.50 | $26.38 |
| Trudy | $12.00 | $5.00 | $17.00 | $3.66 | $4.25 | $24.91 |
| Bill | $5.00 | $5.00 | $10.00 | $2.15 | $2.50 | $14.65 |
| **Total** | **$45.00** | **$20.00** | **$65.00** | **$14.00** | **$16.25** | **$95.25** |