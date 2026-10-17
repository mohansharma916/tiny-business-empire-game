# scenes — owner: Antigravity

Planned scenes (PRD section 7):

| Scene | Release |
|---|---|
| `main_city.tscn` (home; everything else opens over it) | P0 |
| `panels/business_details.tscn` | P0 |
| `panels/business_unlock.tscn` | P0 |
| `panels/offline_earnings.tscn` | P0 |
| `panels/objectives.tscn` | P0 |
| `panels/empire_overview.tscn` | P0 |
| `panels/settings.tscn` | P0 |
| `onboarding/tutorial.tscn` | P0 |
| `panels/leaderboards.tscn` | P1 |
| `actors/customer.tscn` (pooled, max 8 per business) | P0 |

Panels are instantiated once and reused. Opening a full-screen panel pauses the city.
