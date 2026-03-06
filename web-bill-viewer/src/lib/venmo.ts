/**
 * Venmo Universal Link utility.
 *
 * Uses `https://venmo.com/<username>?txn=pay&...` which the OS intercepts
 * when the Venmo app is installed on mobile. On desktop browsers, Venmo's
 * website opens but cannot initiate transactions.
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
  return `https://venmo.com/${user}?txn=pay&amount=${amount}&note=${encodedNote}`;
}
