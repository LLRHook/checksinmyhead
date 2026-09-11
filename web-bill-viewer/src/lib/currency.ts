import type { Bill } from "./api";

const usdFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

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
      fraction: exactCents - wholeCents,
      nameBytes: utf8Encoder.encode(share.person_name),
    };
  });

  remainders.sort(
    (a, b) =>
      b.fraction - a.fraction ||
      compareUTF8(a.nameBytes, b.nameBytes) ||
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
