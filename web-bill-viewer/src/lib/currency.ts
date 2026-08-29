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
