# Enrollment Portfolio: Waitlist Manager + Agentforce Enrollment Assistant

A childcare nonprofit's program enrollment system with an AI assistant on top.

- **Project 1:** programs with fixed capacity, automatic waitlisting, time-limited seat offers, live-updating LWC, and transactional notifications via a platform event.
- **Project 2:** an Agentforce employee agent whose Apex actions reuse the same service layer, so the agent can never break a rule the UI enforces.

The full step-by-step walkthrough is in `docs/Implementation_Guide.pdf`.

## What deploys automatically

| Metadata | Items |
| --- | --- |
| Custom objects | `Program__c`, `Enrollment__c` (master-detail), `Enrollment_Change__e` (platform event, Publish After Commit) |
| Apex | `EnrollmentService`, `EnrollmentTriggerHandler`, `EnrollmentController`, `OfferExpirationJob`, 3 invocable agent actions, `TestDataFactory`, 3 test classes |
| Triggers | `EnrollmentTrigger`, `ProgramTrigger` |
| LWC | `programEnrollment` (record page component for Program__c) |
| Security | `Enrollment_Coordinator` permission set, `Program__c` tab |

## What you configure by hand (about 30 minutes)

These are set up in the UI because their metadata varies by org and release, and a failure in one would roll back the whole deployment:

1. Drag **Program Enrollment** onto the Program__c Lightning record page.
2. Platform-event-triggered Flow for notification emails (guide, Project 1 step 3d).
3. Prompt template **Draft Family Update** (guide, Project 2 step 2d).
4. The **Enrollment Assistant** agent, its topic, instructions and actions (guide, Project 2 step 3).

## Deploy with the Salesforce CLI (recommended)

Run these from this folder (`enrollment-portfolio/`, where `sfdx-project.json` lives). Open this folder, not the repo root, in VS Code so the Salesforce extensions activate.

```bash
sf org login web --alias portfolio --set-default
sf project deploy start --manifest manifest/package.xml
sf org assign permset --name Enrollment_Coordinator
sf apex run --file scripts/apex/seed.apex
sf apex run --file scripts/apex/schedule-expiry.apex
sf apex run test --code-coverage --result-format human --wait 10
```

**Why the first deploy runs no tests:** new custom fields deployed through the Metadata API are hidden from every profile, System Administrator included, until a permission set grants them. `EnrollmentControllerTest` and `AgentActionsTest` exercise `WITH USER_MODE` queries, so they only pass once `Enrollment_Coordinator` is assigned to the user running them. A Developer Edition org runs no tests on deploy by default, so deploy first, assign the permission set, then run the suite. Later deploys can add `--test-level RunLocalTests`.

After changing things in the org, pull them back and commit:

```bash
sf project retrieve start --manifest manifest/package.xml
```

## Deploy without the CLI (Workbench)

1. Log in to https://workbench.developerforce.com with your org.
2. Migration, Deploy. Choose `dist/enrollment-portfolio-deploy.zip` (Metadata API format with `package.xml` at the root).
3. Tick **Single Package** and **Rollback On Error**. Leave Test Level as default for a Developer Edition org.
4. Deploy, then assign the permission set in Setup and run the scripts in `scripts/apex` from the Developer Console (Debug, Open Execute Anonymous Window).

The zip is generated from `force-app`. After changing the source, rebuild it with `./scripts/build-deploy-zip.sh` (needs the CLI) and commit the result.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/apex/seed.apex` | 4 programs, 24 families, waitlists, and one pending offer (Maria Lopez, Infant Care) |
| `scripts/apex/reset.apex` | Deletes the demo data so you can reseed before recording |
| `scripts/apex/schedule-expiry.apex` | Schedules the hourly offer-expiration batch |
| `scripts/build-deploy-zip.sh` | Rebuilds `dist/enrollment-portfolio-deploy.zip` for Workbench from the current source |

Change `emailDomain` in `seed.apex` to your own domain (or use plus-addressing) so demo emails reach you.

## Key design decisions

- **Concurrency:** `FOR UPDATE` on the program row prevents two coordinators from taking the last seat at once.
- **One service layer:** trigger, LWC, batch and agent all call `EnrollmentService`.
- **Explicit state machine:** allowed transitions live in one map; invalid moves throw a clear error.
- **Queue order:** `Waitlisted_At__c` with the auto-number Name as a tie-breaker, so positions never need renumbering.
- **Bulk safety:** `fillOpenSeats` uses three queries and one DML for any number of programs.
- **Transactional notifications:** Publish After Commit means no email for a rolled-back change.
- **Security:** `with sharing`, `WITH USER_MODE` queries, and a dedicated permission set.

## Differences from the Implementation Guide

The code in `force-app` matches the guide's listings, with these deploy fixes:

- The `Program__c` tab style is `Custom57: Building Block`. The shipped `Custom57: Building` is not a valid tab motif.
- The CLI steps above deploy first and run tests after assigning the permission set, instead of deploying with `--test-level RunLocalTests` (see the note under the CLI steps).
- The Workbench zip lives at `dist/enrollment-portfolio-deploy.zip` and is rebuilt from source by `scripts/build-deploy-zip.sh`.
