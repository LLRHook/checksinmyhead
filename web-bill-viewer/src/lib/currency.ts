import type { Bill } from "./api";

const usdFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export function formatMoney(amount: number, currency = "USD"): string {
  const normalizedCurrency = currency.toUpperCase();
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency: normalizedCurrency,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${normalizedCurrency} ${amount.toFixed(2)}`;
  }
}

// Presentation only. Never use this value in a request or an allocation.
export function billTotalForDisplay(
  total: number,
  shares: number[] = [],
): number {
  if (
    !Number.isFinite(total) ||
    total < 0 ||
    total * 100 > Number.MAX_SAFE_INTEGER
  )
    return total;
  const rounded = Math.round(total * 100) / 100;
  let cents = 0;
  for (const share of shares) {
    if (!Number.isFinite(share) || share < 0) return total;
    const shareCents = Math.round(share * 100);
    const shareNoise = 4 * Number.EPSILON * Math.max(1, share);
    if (Math.abs(share - shareCents / 100) > shareNoise) return total;
    cents += shareCents;
  }
  const noise = 4 * Number.EPSILON * Math.max(1, total);
  // Preserve genuine cent disagreements (BUG-1794264955), including each
  // renderer's previous formatting. Never choose a share sum as the bill total.
  if (
    shares.length > 0 &&
    cents !== Math.round(total * 100) &&
    Math.abs(cents / 100 - total) <= 0.01 + noise
  )
    return total;
  return rounded;
}

type BillDisplayAmounts = Pick<
  Bill,
  "total" | "display_total" | "display_currency" | "currency_code"
> & {
  person_shares: { total: number }[];
};

export function billDisplayTotal(bill: BillDisplayAmounts): number {
  const original = bill.currency_code?.trim().toUpperCase() || "USD";
  const display = bill.display_currency?.trim().toUpperCase() || original;
  // Shares remain in receipt currency. Never sum native shares into a converted
  // total or replace a frozen conversion with a fresh rate.
  return billTotalForDisplay(
    bill.display_total ?? bill.total,
    display === original ? bill.person_shares.map((share) => share.total) : [],
  );
}

function roundMoney(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

const utf8Encoder = new TextEncoder();

function compareUTF8(left: Uint8Array, right: Uint8Array): number {
  const length = Math.min(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return left.length - right.length;
}

export function billCurrencyCode(bill: Bill): string {
  return bill.currency_code?.trim().toUpperCase() || "USD";
}

export function billUSDExchangeRate(bill: Bill): number {
  const rate = bill.usd_exchange_rate;
  return typeof rate === "number" && Number.isFinite(rate) && rate > 0
    ? rate
    : 1;
}

export function toUSD(value: number, bill: Bill): number {
  return roundMoney(value * billUSDExchangeRate(bill));
}

export function billUSDTotal(bill: Bill): number {
  return typeof bill.usd_total === "number" && Number.isFinite(bill.usd_total)
    ? bill.usd_total
    : toUSD(bill.total, bill);
}

// Convert all shares as one allocation. Fully assigned shares add back to the
// immutable USD bill total; partial assignments keep only their assigned value.
// This mirrors the backend's deterministic largest-remainder rule.
export function allocateBillUSDShareAmounts(bill: Bill): number[] {
  const shares = bill.person_shares;
  const result = new Array<number>(shares.length).fill(0);
  if (!shares.length) return result;

  const shareTotal = shares.reduce(
    (sum, share) => sum + Math.max(share.total, 0),
    0,
  );
  if (shareTotal <= 0) return result;

  const targetCents =
    Math.abs(shareTotal - bill.total) < 0.005
      ? Math.round(billUSDTotal(bill) * 100)
      : Math.round(shareTotal * billUSDExchangeRate(bill) * 100);
  if (targetCents <= 0) return result;

  const remainders = shares.map((share, index) => {
    const exactCents = (targetCents * Math.max(share.total, 0)) / shareTotal;
    const wholeCents = Math.floor(exactCents);
    result[index] = wholeCents;
    return {
      index,
      ordinal:
        bill.participants?.findIndex(
          (p) => p.participant_id === share.participant_id,
        ) ?? index,
      fraction: exactCents - wholeCents,
      nameBytes: utf8Encoder.encode(share.person_name),
    };
  });

  remainders.sort(
    (a, b) =>
      b.fraction - a.fraction ||
      compareUTF8(a.nameBytes, b.nameBytes) ||
      a.ordinal - b.ordinal ||
      a.index - b.index,
  );
  const allocated = result.reduce((sum, cents) => sum + cents, 0);
  for (let i = 0; i < targetCents - allocated; i += 1) {
    result[remainders[i % remainders.length].index] += 1;
  }

  return result.map((cents) => cents / 100);
}

export function formatUSDMoney(value: number): string {
  return `${usdFormatter.format(value)} USD`;
}

export function formatUSDExchangeRate(value: number): string {
  return `$${value.toLocaleString("en-US", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 6,
  })} USD`;
}

export function formatOriginalMoney(value: number, bill: Bill): string {
  const currency = billCurrencyCode(bill);
  if (currency === "USD") return formatUSDMoney(value);

  try {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency,
      currencyDisplay: "code",
    }).format(value);
  } catch {
    return `${currency} ${value.toFixed(2)}`;
  }
}
