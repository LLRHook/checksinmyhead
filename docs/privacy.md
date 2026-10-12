# Billington Privacy Policy

**Effective October 12, 2026**

Billington is an account-free bill-splitting app, but it is not fully local. Some information stays on your device; bills and shared tabs you choose to create are sent to Billington's online service so they can be shared.

## Information we handle

- **Bills and tabs:** Names, receipt line items and amounts, participant names, split and payment status, optional payment handles, and tab member display names. This information is stored in the Billington database and shown to people with the relevant share link.
- **Access credentials:** Random access and member tokens are used instead of accounts. The app stores some tokens on your device; web links contain an access token. The web host receives that link to render the shared page, and Billington's API receives the token to authorize access. Anyone with a valid share link may be able to view or update associated content, so treat it like a private key.
- **Receipt scans:** If you choose receipt scanning, the selected image is sent to Billington's API and then to Anthropic's Claude API to extract receipt details. The parser returns extracted text and amounts; this code path does not save the uploaded image in Billington's database. Anthropic says it normally deletes API inputs and outputs within 30 days, subject to exceptions in its [retention terms](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data).
- **Currency conversion:** Currency requests may be sent by our API to Frankfurter or, when configured, ExchangeRate-API. These requests contain currency codes, not bill contents.
- **Technical request data:** The API logs request IP address, path, response status, and timing. Share tokens are not included in the API's request path logs. Slow database query logs may include SQL statements and values. Hosting and infrastructure providers may also process technical data needed to operate the service.
- **Local app and browser data:** The app stores bill history, participant names, preferences, and tab/token data on your device. The web viewer stores some lazy-bill participant details in your browser's local storage.

## How we use and share information

We use this information to create and share bills and tabs, calculate splits, remember local preferences, prevent abuse of receipt scanning, and operate and secure the service. We do not sell bill or tab content.

Information is processed by the providers needed for the feature you use: Anthropic for receipt scanning, currency-rate providers for conversion, and infrastructure providers for hosting and database operations. Current builds connect to an API hosted on Render and a viewer hosted on Vercel; the database provider is selected through deployment configuration. See [Render's privacy policy](https://render.com/privacy) and [Vercel's privacy notice](https://vercel.com/legal/privacy-notice). When you follow a payment link, the payment service you choose handles that interaction under its own policy.

## Storage, retention, and choices

Shared bills and tabs remain in the online database until removed by service operators. There is no in-app control to delete a bill or tab, and share tokens do not currently expire automatically. Local app data can be removed by clearing app data or uninstalling; browser data can be cleared in browser settings. Removing local data does not remove a copy already shared online.

To ask about or request removal of shared information, email [checkmateapp@duck.com](mailto:checkmateapp@duck.com) and include the relevant bill or tab link. Because there are no accounts, we may need enough information to verify control of the content before acting. Copies in backups or provider logs may persist according to the relevant provider's retention practices.

## Changes

We may update this policy as the service changes; the latest version and its effective date will appear here.

## Contact

Privacy questions and requests: [checkmateapp@duck.com](mailto:checkmateapp@duck.com).
