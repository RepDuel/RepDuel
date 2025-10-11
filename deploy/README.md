# Web deployment playbook

This directory documents how the Flutter web frontend is packaged and deployed to Render via the `Deploy Web` GitHub Actions workflow.

## Pipeline overview

The workflow (`.github/workflows/deploy-web.yml`) runs on every push to `main` and on manual dispatch. It performs the following hard-gated stages:

1. Checkout the repository on a fresh runner.
2. Install Python dependencies and run the FastAPI backend test suite (including the Stripe webhook signature tests).
3. Install and cache Flutter 3.22.0 toolchains and dependencies.
4. Build the Flutter web bundle in release mode with all configuration supplied via `--dart-define` values from GitHub secrets.
5. Stage the bundle into `deploy/public/` and enforce sanity checks (presence of `index.html`, hashed asset manifest, and no `localhost` URLs).
6. Trigger the Render Static Site deploy hook.
7. Poll the production site (`/login`) until a `200 OK` is returned to confirm the rollout.

Successful runs leave behind no build artefacts in git, keeping the repo immutable.

### Required GitHub secrets

| Secret | Purpose |
| --- | --- |
| `BACKEND_URL` | Public HTTPS endpoint for the FastAPI backend (`https://api.repduel.com`). |
| `PUBLIC_BASE_URL` | Production web origin (`https://www.repduel.com`). |
| `MERCHANT_DISPLAY_NAME` | Display name shown in Stripe Checkout. |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key for the web client. |
| `STRIPE_PREMIUM_PLAN_ID` | Stripe price ID for the premium subscription. |
| `STRIPE_SUCCESS_URL` | Absolute URL for the post-checkout success redirect. |
| `STRIPE_CANCEL_URL` | Absolute URL for the post-checkout cancellation redirect. |
| `REVENUE_CAT_APPLE_KEY` | RevenueCat Apple key for mobile builds. |
| `STRIPE_TEST_SECRET_KEY` | Stripe test secret, used during pytest runs. |
| `STRIPE_TEST_WEBHOOK_SECRET` | Stripe webhook secret for signature verification tests. |
| `RENDER_DEPLOY_HOOK` | Render Static Site deploy hook URL. |
| `PAYMENTS_ENABLED` (optional) | Set to `true` to enable premium flows in production. Omit or set to `false` to keep payments disabled by default. |

Secrets are never committed; they are injected at runtime by the workflow.

## Rollback and safety

Render keeps the last five deploys by default. To roll back:

1. Visit **Render → repduel-web → Deploys**.
2. Locate the last known-good deploy within the most recent five entries.
3. Select **Rollback** to redeploy that snapshot. The static bundle in `deploy/public/` is immutable, so the rollback is instantaneous.
4. Monitor the smoke probe (GitHub Actions job) and your external uptime checks to confirm recovery.

To undo a bad code change, revert the offending commit in git and allow CI to rebuild from source; no manual artefacts are required.

### Feature flag: payments

Premium purchase entry points are protected by the `PAYMENTS_ENABLED` flag exposed via `Env.paymentsEnabled`.

- **Default**: `false` (premium features hidden and checkout disabled).
- **Enable**: set the `PAYMENTS_ENABLED` secret to `true` and re-run the `Deploy Web` workflow (or wait for the next `main` push). Disable by removing or resetting the secret to `false`.
- The UI shows a maintenance message while disabled, preventing new checkouts and Stripe API calls.

### Monitoring and guardrails

- Configure an external uptime monitor (Statuspage, Healthchecks, etc.) to ping:
  - `https://www.repduel.com/login` (overall availability).
  - `https://www.repduel.com/subscribe` (premium entry point; expect HTTP 200 with maintenance banner when payments are disabled).
- Alert on non-200 responses or spikes in latency.
- Use Render metrics/logs to observe deploy status and set up alerts for deploy hook failures.

Keeping these probes active ensures that regressions are caught quickly and deployments remain reversible.
