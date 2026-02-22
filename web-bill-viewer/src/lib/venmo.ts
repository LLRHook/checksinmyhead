/**
 * Venmo deep link and web fallback utilities.
 *
 * Mobile browsers cannot guarantee the native `venmo://` scheme will open the
 * app. Using an `<a href="venmo://...">` fires the native intent, while a
 * setTimeout-based fallback redirects to the Venmo web pay page if the app
 * didn't handle the link within 1.5 seconds.
 */

function cleanUsername(username: string): string {
  return username.replace(/^@/, "");
}

/**
 * Build a `venmo://` deep link URL for the native Venmo app.
 */
export function buildVenmoDeepLink(
  username: string,
  amount: string,
  note: string,
): string {
  const user = cleanUsername(username);
  const encodedNote = encodeURIComponent(note);
  return `venmo://paycharge?txn=pay&recipients=${user}&amount=${amount}&note=${encodedNote}`;
}

/**
 * Build a Venmo web pay URL as a fallback when the native app isn't installed.
 */
export function buildVenmoWebUrl(
  username: string,
  amount: string,
  note: string,
): string {
  const user = cleanUsername(username);
  const encodedNote = encodeURIComponent(note);
  return `https://account.venmo.com/pay?recipients=${user}&amount=${amount}&note=${encodedNote}`;
}

/**
 * Start a 1.5-second fallback timer that redirects to the Venmo web URL if the
 * native app didn't open. Returns the timer ID so it can be cleared externally
 * if needed.
 */
export function startVenmoFallback(
  username: string,
  amount: string,
  note: string,
): ReturnType<typeof setTimeout> {
  const webUrl = buildVenmoWebUrl(username, amount, note);
  return setTimeout(() => {
    window.location.href = webUrl;
  }, 1500);
}
