# Privacy

Billington is designed to minimize the personal information it collects and stores. This document explains the privacy model and how it compares to alternatives.

## How It Works

Billington uses **anonymous member tokens** instead of user accounts. No email, phone number, password, or social login is ever collected.

### What Billington Stores

- **Display names**: User-chosen names (e.g. "Alice") — not verified, not unique
- **Bill data**: Item names, prices, split calculations
- **Access tokens**: Cryptographic strings for link-based sharing
- **Member tokens**: Per-member tokens for attribution within a tab
- **Receipt images**: Uploaded photos stored on the server

### What Billington Does Not Store

- Email addresses
- Phone numbers
- Passwords
- Social media accounts
- Device identifiers
- Location data
- Analytics or tracking data

## Anonymous Token Model

When a user creates a tab, they receive an **access token** (for sharing the tab link) and optionally a **member token** (for attributing their contributions). These tokens are:

- Generated using Go's `crypto/rand.Text()` (cryptographically secure)
- 64 characters long
- Stored locally on the user's device (Flutter: SharedPreferences, Web: localStorage)
- Not linked to any identity system

Anyone with the access token can view the tab. Member tokens provide write attribution but do not grant additional read access.

## Mobile App Privacy

The Flutter app stores data locally using Drift (SQLite):

- Recent bills (last 30) stored on-device
- Recent participants (last 12) for quick selection
- Tab metadata and member tokens in local database
- No analytics SDK, no crash reporting that sends PII
- Network requests only go to the Billington backend

## Comparison

| | Billington | Splitwise | Venmo |
|---|---|---|---|
| Account required | No | Yes (email) | Yes (phone + SSN) |
| PII collected | Display name only | Name, email, phone | Name, email, phone, SSN, bank |
| Social graph | None | Friend lists | Friend lists + transactions |
| Data sold to third parties | No | Privacy policy allows | Privacy policy allows |
| Works offline | Yes (local bills) | No | No |
| Open source | Yes (GPL) | No | No |

## Data Lifecycle

- **Bills**: Persist until the tab is deleted or the server is wiped
- **Images**: Stored on the server filesystem, deleted when removed via API
- **Tokens**: No expiration — access lasts as long as the data exists
- **Local data**: Cleared when the user uninstalls the app or clears app data

## Security Considerations

- All tokens are generated with cryptographic randomness
- No authentication means no credential stuffing or password reuse risk
- CORS is open (by design — links are meant to be shared publicly)
- Image uploads are rate-limited and size-restricted
- No session cookies or JWT tokens to steal
