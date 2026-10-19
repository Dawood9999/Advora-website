# AdVora Production Readiness Review
Date: 2026-10-19
Reviewed file: index.html
Reviewed branch: production-upgrade
Reviewed source commit/blob: 0a3b2b8db04e4e5fb36218a7606c6eb76af0ab67

## Current state
- The repository contains a single-page English demo app.
- Registration, login, package activation, daily video reward, referral tree, referral commission, demo withdrawal calculation, activity history, and demo backup/import functions exist in the client-side JavaScript.
- Package limits in the source are $10 => 3 videos/day, $30 => 6, $50 => 10, and $100 => 15.
- The page explicitly states that no real deposits or payouts are processed.
- User records and balances are stored in browser localStorage. Session name is stored client-side.
- Login compares the entered password with the saved plaintext password.
- Withdrawal currently changes the local demo balances and writes a record with status "Demo request submitted"; it does not connect to a payout provider or a server.
- No server API calls or external script dependencies were found in index.html.

## Blocking items before real users or real money
1. Implement a server-side backend and persistent database; never treat localStorage as authoritative balances.
2. Replace plaintext passwords with server-side password hashing and secure session handling.
3. Enforce package activation, daily reward limits, commission calculation, and withdrawal rules on the server, with atomic transactions and audit logs.
4. Add server-side validation, authorization, rate limiting, CSRF/session protections as applicable, and account recovery.
5. Integrate a legitimate payment provider only after its account, API credentials, compliance requirements, and supported countries are verified. Do not store secret keys in the HTML or GitHub repository.
6. Define whether demo account data can be migrated. The existing browser backup/export includes account details and plaintext passwords; it must be treated as sensitive and must not be uploaded publicly.
7. Add automated tests for registration/login, referrals, duplicate/cyclic referral relationships, daily limits, commission rounding, insufficient balances, and concurrent withdrawal requests.
8. Verify responsive layout, accessibility, error states, and deployment behavior in real browsers.

## Safe next steps
- Keep the current main branch and existing demo data unchanged.
- Build and test changes on the `production-upgrade` branch.
- Use a separate test environment and synthetic accounts for any backend migration.
- Do not test a real withdrawal or use real funds until backend accounting and payment integration are reviewed.
- A custom domain can be attached later; a domain does not provide a backend or make client-side balances secure.

## Scope of this review
This was a static source-code review, not a live browser test or security audit. It does not certify the app as production-ready.
