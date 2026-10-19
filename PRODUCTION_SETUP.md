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

## Selected crypto network: USDT on BNB Smart Chain (BEP20)

The requested deposit/withdrawal network is BEP20 on BNB Smart Chain. The draft SQL now uses USDT accounting units (1 USDT = 1,000,000 micro-USDT units), marks payment orders as BEP20 / chain ID 56, and records BEP20 on withdrawal requests. This is only a schema draft; it does not connect to a wallet, monitor the chain, or send transactions.

Before any live funds are accepted:
- Confirm the exact official USDT token contract for BNB Smart Chain from Tether's official documentation and configure it server-side; never trust a token name/symbol alone.
- Decide the custody model and use a reputable provider or professionally reviewed wallet infrastructure. Never store seed phrases/private keys in GitHub, frontend code, or chat.
- Generate a unique deposit address per user/order where possible, or use a provider with reliable deposit attribution; define how confirmations, reorgs, wrong-network transfers, underpayments, overpayments, and duplicate events are handled.
- A trusted server-side watcher/provider webhook must verify chain ID 56, token contract, destination, amount, transaction receipt/status, and required confirmations before crediting a deposit. Make processing idempotent and reconcile against chain/provider records.
- Withdrawals must be server-side, manually reviewed at first, check available balance and risk controls in a database transaction, apply rate limits and address checks, and use idempotency plus an auditable payment reference. Do not claim a withdrawal is paid until the chain transaction is independently verified.
- Define fees, minimum/maximum limits, processing times, refund/error handling, customer support, sanctions/AML obligations where applicable, and secure operational key management before launch.
- Use a testnet or provider sandbox for integration tests first. Testnet tokens have no real value. Do not enable live transfers until security review and provider/business approvals are complete.

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
