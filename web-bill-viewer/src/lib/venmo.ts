/**
 * Venmo Universal Link utility.
 *
 * Uses `https://venmo.com/pay?...` which the OS intercepts when the Venmo app
 * is installed, and falls back to Venmo's web experience naturally.
 */

function cleanUsername(username: string): string {
  return username.replace(/^@/, "");
}

/**
 * Build a Venmo Universal Link pay URL.
 */
export function buildVenmoPayUrl(
  username: string,
  amount: string,
  note: string,
): string {
  const user = cleanUsername(username);
  const encodedNote = encodeURIComponent(note);
  return `https://venmo.com/pay?recipients=${user}&amount=${amount}&note=${encodedNote}`;
}
