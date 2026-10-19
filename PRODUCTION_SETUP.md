# AdVora: Demo Completion and Production Setup

This plan is intentionally separate from the live `main` branch. The current GitHub Pages site remains a demo and should not accept real funds.

## Current demo

- Static single-page HTML application hosted on GitHub Pages.
- Account details and balances are stored in browser localStorage; they do not synchronize across devices.
- The current demo's account export can include plaintext passwords. Treat exports as sensitive and never upload them to GitHub or send them in chat.
- Automated Playwright tests currently cover demo registration, activation of the $10 demo package, the 3-claim daily limit, the $0.51 demo reward total, and persistence after reload.
- Do not run tests using existing accounts: use a newly generated synthetic account. Do not rerun the one-time Safe Commission Test on existing demo accounts.

## Proposed architecture

1. **Frontend:** retain the existing demo untouched while building a separate authenticated production frontend.
2. **Identity and database:** Supabase Auth + PostgreSQL. Use server-side authentication, email verification and password recovery. Enable Row Level Security on every exposed table. Never use a service-role key in frontend code.
3. **Business rules:** put package activation, daily claim limits, reward calculation, referral commissions, balance checks and withdrawal requests into trusted server-side Edge Functions or database functions. The browser must never decide its own balance.
4. **Accounting:** record every credit/debit in an append-only ledger using integer paisa, unique idempotency keys, database transactions and audit events. Avoid floating-point currency arithmetic.
5. **Payments:** start with provider sandbox only. Create orders server-side, verify signed provider webhooks server-side, and only activate packages after a verified successful transaction. A redirect back to the website is not proof of payment.
6. **Withdrawals:** start as manually reviewed requests; do not promise automated payouts until a provider confirms that merchant payouts are supported and the account is approved. Use a separate authorization and audit trail for approval/payment.
7. **Deployment:** GitHub Pages cannot host trusted server secrets or server functions. Deploy the production frontend separately or use a supported hosting integration; keep all secrets in the server provider's secret manager.
8. **Operations:** define privacy policy, terms, refund policy, support contact, data retention, backups, incident response, and a clear lawful source of funds/revenue before onboarding customers.

## Suggested first backend schema

See `backend/supabase/migrations/001_initial_schema.sql`. It is a foundation for review, not a certified production migration. It intentionally does not enable package prices, payment acceptance, or payouts. The server-side functions and additional tests must be implemented and reviewed before using real users or funds.

## Free-tier and cost notes

Supabase advertises a Free plan for experimentation, with limits and pausing after a period of inactivity. It does not include automatic backups on the Free plan. Confirm current quotas and costs before launch; a free development environment is not a substitute for production backups and operational support.

## Payment provider research (Pakistan)

Safepay publishes a sandbox environment for integration testing and says a production account requires onboarding and KYC. Live payment acceptance is not automatic just because an account is created. Confirm with the provider that AdVora's specific business model, payment purpose, refunds, and any intended payouts are permitted before implementing live flows. Never commit API secrets to this repository.

## Launch blockers

- Complete server-side functions and tests for duplicate claims, time zones/day boundaries, referral cycles, commissions, idempotency, insufficient funds and concurrent withdrawals.
- Validate database permissions and Row Level Security with separate test users.
- Test provider sandbox payments and verified webhooks.
- Confirm business/legal suitability and payment-provider written approval.
- Configure monitoring, backups, privacy and customer support.
- Complete responsive, accessibility, security and recovery tests.
- Keep real deposits and payouts disabled until every blocker is resolved.
