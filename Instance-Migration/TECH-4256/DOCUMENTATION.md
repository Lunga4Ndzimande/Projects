# TECH-4256 — Instance Migration | Client Linking (Trial Clients)

**Author:** Lunga Ndzimande
**Ticket:** TECH-4256 (references TECH-4533, TECH-1675, TECH-1720)
**Environment:** UK (Development, Staging, Production)
**Database:** UDM__ (SingleStore)
**Status:** Completed ✅

---

## Background

This ticket linked the Instance Migration trial clients — Carne (Cantor, GAM, ManCo) and CCLA — across their Development, Staging and Production environments in the UK region.

Scripts for these clients were written and peer reviewed on TECH-4533. This ticket executed them.

Clients already linked under TECH-1675 were excluded. Remaining clients are tracked on TECH-4684.

---

## What Client Linking Does

Each client exists in three environments: Development, Staging and Production. Linking them inserts a shared `linkId` into the `ClientLink` table so the Instance Migration feature knows they belong to the same client group.

Two things are required before a client can use Instance Migration:
1. `ClientLink` records inserted (links the three environments together)
2. `FEATURE_INSTANCE_MIGRATION` flag enabled in `ClientConfiguration`

---

## Client ID Confirmation

| Client | Environment | clientId |
|--------|-------------|----------|
| Carne - Cantor | Development | 2243 |
| Carne - Cantor | Staging | 2242 |
| Carne - Cantor | Production | 2241 |
| Carne - GAM | Development | 2229 |
| Carne - GAM | Staging | 2230 |
| Carne - GAM | Production | 2231 |
| Carne - ManCo | Development | 2232 |
| Carne - ManCo | Staging | 2233 |
| Carne - ManCo | Production | 2234 |
| CCLA | Development | 2237 |
| CCLA | Staging | 2238 |
| CCLA | Production | 2239 |

---

## Process Overview

```
1. Client Confirmation   — verify clientIds against Client and ClientLink tables
2. Pre-validation        — confirm no existing ClientLink rows for target clientIds
3. Link clients          — INSERT into ClientLink using MAX(linkId) + 1
4. Enable feature flag   — INSERT/UPDATE FEATURE_INSTANCE_MIGRATION in ClientConfiguration
5. Update TableId        — run ONCE after all clients are linked (final step)
6. Verify               — confirm linking and feature flag are correct
7. Peer Review          — approved by Tashvir Babulal and Yogeshwar Phull
8. Deployment           — executed in morning deployment window (7:30am)
```

---

## Key Technical Notes

- `linkId` is calculated using `MAX(linkId) + 1` from `ClientLink` — deterministic and safe
- `clientConfigurationId` is calculated using `COALESCE(MAX(clientConfigurationId), 0) + 1`
- `ClientLink` has a `TableId` entry but it is not used by the application on this path — intentionally not updated (confirmed by peer review)
- `TableId` for `ClientConfiguration` is updated ONCE at the very end after all clients are linked
- Scripts use `ON DUPLICATE KEY UPDATE` to safely handle cases where the flag row already exists

---

## Peer Review

| Reviewer | Status |
|----------|--------|
| Tashvir Babulal | ✅ Approved |
| Yogeshwar Phull | ✅ Approved |

Note from Tashvir: ClientLink has a TableId entry but it is not used yet. Rayhaan confirmed this is intentional — same approach as TECH-1720.

---

## Execution Summary

| Client | Linked | Feature Flag Enabled |
|--------|--------|----------------------|
| Carne - Cantor | ✅ | ✅ |
| Carne - GAM | ✅ | ✅ |
| Carne - ManCo | ✅ | ✅ |
| CCLA | ✅ | ✅ |

Evidence captured in CC-8830. Ticket closed by Rayhaan Suleyman.

---

## Scripts

| Script | Purpose |
|--------|---------|
| `script_carne_cantor.sql` | Link Carne Cantor + enable feature flag |
| `script_carne_gam.sql` | Link Carne GAM + enable feature flag |
| `script_carne_manco.sql` | Link Carne ManCo + enable feature flag |
| `script_ccla.sql` | Link CCLA + enable feature flag |
| `script_final_tableid_update.sql` | Update TableId — run ONCE after all clients linked |

---

## References

- TECH-4533 — scripts written and peer reviewed here
- TECH-1675 — clients already linked (excluded from this ticket)
- TECH-1720 — used as guidance for linking approach
- TECH-4684 — remaining clients not covered here
- CC-8830 — Change Control with execution evidence
- CC-8834 — Carne GAM CC (Dev, Staging, Prod, UK)
- CC-8844 — Carne ManCo and Cantor CC (Dev, Staging, Prod, UK)
