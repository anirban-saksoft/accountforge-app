# AccountForge

A Salesforce demo app with intentionally broken Apex, wired to report real caught errors to an AI-driven issue-triage pipeline. When `AccountEnrichmentService.enrichAccountsWithContactData` fails, `ErrorCapture` reports the exact error (class, method, stack trace, user) to an n8n webhook, where an AI agent reads the source straight from this repo, diagnoses the root cause, and opens a GitHub Issue and pull request automatically.

## What's in here

- **`force-app/main/default/classes/`** — `AccountEnrichmentService` (contains 3 intentional bugs: SOQL-in-loop, empty-list access, null dereference), `CaseEscalationService` (a second, separate bug catalog — DML-in-loop, bad `Integer.valueOf`, divide-by-zero — not wired to the triage pipeline), `ErrorCapture` (builds the error payload and posts it to n8n via Named Credential).
- **`force-app/main/default/lwc/accountEnrichmentPanel/`** — the demo UI: lists Accounts, lets you select some, and calls the buggy enrichment method.
- **`force-app/main/default/lwc/accountDashboard/`** — a read-only Account/Contact detail view.
- **`force-app/main/default/lwc/caseEscalationPanel/`** — the UI for `CaseEscalationService`'s bug catalog.
- **`force-app/main/default/namedCredentials/`, `externalCredentials/`** — the outbound callout to the n8n webhook. The actual secret value is never stored here — it's entered directly in Setup on each org this gets deployed to.
- **`force-app/main/default/permissionsets/Triage_Agent_Access_PermissionSet`** — grants access to the above so a test user can actually run the demo.

## Deploy

```
sf project deploy start
```

After deploying to a new org:
1. Set the real secret on the External Credential's principal in Setup (Named Credentials → External Credentials).
2. Assign `Triage Agent - Access PermissionSet` to your user.
3. Add the `accountEnrichmentPanel` component to a Lightning App Page (Lightning App Builder).

### Auto-deploy on merge

A GitHub Actions workflow (`.github/workflows/deploy.yml`) runs `sf project deploy start` automatically on every push to `main` — in practice, every time a PR merges. It authenticates using a one-time `SFDX_AUTH_URL` repository secret (Settings → Secrets and variables → Actions), generated once via:

```
sf org auth show-sfdx-auth-url -o <your-org-alias>
```

This is purely additive — the manual deploy steps above still work exactly as documented; the workflow just does the same thing automatically after a merge.

See the demo setup guide in the parent project for the full walkthrough and test scenarios.
