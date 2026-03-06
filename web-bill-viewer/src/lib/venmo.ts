/**
 * Venmo deeplink utility.
 *
 * Uses the `venmo://` custom URL scheme to open the Venmo app directly,
 * bypassing universal link issues where clicking a venmo.com link from
 * a webpage navigates to the website instead of opening the app.
 */

function cleanUsername(username: string): string {
  return username.replace(/^@/, "");
}

/**
 * Build a Venmo deeplink URL that opens the app directly.
 */
export function buildVenmoPayUrl(
  username: string,
  amount: string,
  note: string,
): string {
  const user = cleanUsername(username);
  const encodedNote = encodeURIComponent(note);
  return `venmo://paycharge?txn=pay&recipients=${user}&amount=${amount}&note=${encodedNote}`;
}
