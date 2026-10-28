# Official Garmin evidence and founder access actions

All URLs below were retrieved **2026-10-28 (Asia/Makassar)** using documentation
retrieval only. No authenticated portal, browser or desktop control. These are
public capabilities, not evidence that Cohort has access. Paraphrases are bounded;
exact live endpoint/payload/permission details must come from the authorised portal.

## Public source register

| ID | Official source | Verified scope / limit |
|---|---|---|
| G1 | [Program overview](https://developer.garmin.com/gc-developer-program/overview/) | Personal: own data, pull, Activity/Health/Women's Health; Training is not listed. Business Starter lists Training and Activity (JSON/FIT), limited users, push-only, no history. Enterprise offers push or ping/pull, history and tailored commercial terms. No numeric Starter cap or Cohort entitlement is stated. |
| G2 | [Training API](https://developer.garmin.com/gc-developer-program/enterprise/training-api/) | Consented workouts/plans go to Garmin Connect calendar, then compatible devices through sync. REST; new devices with workout features supported. Endpoint names, schedule date semantics, payload schema, mutation/idempotency and readback guarantees are not public here. |
| G3 | [Activity API](https://developer.garmin.com/gc-developer-program/enterprise/activity-api/) | Consented device sync makes recorded activity available; JSON summaries and FIT details. Page describes push/ping-pull, sample tools and pre-production auto-verification. Read with G1: Starter is push-only; starred backfill/multi-project features require Enterprise. Do not assume Starter polling/history or a sandbox. |
| G4 | [Program FAQ](https://developer.garmin.com/gc-developer-program/enterprise/program-faq/) | OAuth 2.0; multiple APIs in one app; individual developers/startups eligible. Describes immediate Starter access but also an approved request before detailed portal documentation. No guaranteed approval time or Cohort status. Connect IQ is a separate program. |
| G5 | [Request access](https://www.garmin.com/en-US/forms/StarterGarminConnectDeveloperAccess/) | Current official request destination, reached from G4. Retrieval shows a JavaScript-required form shell; fields/eligibility attestations/current submission state were not visible. No form was executed or submitted. |
| G6 | [Developer Portal](https://developerportal.garmin.com/) | Unauthenticated login screen. Detailed Training/Activity/OAuth/revocation/callback contracts unavailable in this audit. No login attempted. |
| G7 | [FIT Workout contract](https://developer.garmin.com/fit/articles/file-types/workout.html) | Indexed steps, repeat blocks, intensities, custom ranges, numerical HR encoding. FIT semantics do not establish Training API JSON fields or device support. |
| G8 | [Official Garmin FIT SDK profile](https://raw.githubusercontent.com/garmin/fit-javascript-sdk/refs/heads/main/src/profile.js) | Retrieved profile reports 21.214.0Release (tag production/release/21.214.0-0-g47b86b1f). Message 27 duration/speed units/scales; message 72 trainingFile reference. Pin a verified SDK revision before implementation; this moving URL is an observation, not a dependency lock. |
| G9 | [FIT Activity contract](https://developer.garmin.com/fit/articles/file-types/activity.html) | Sessions/laps, elapsed vs timer time; Workout/Workout Step messages optional. Workout-step lap references typical, not universal. Neither arbitrary title equality nor file existence guarantees a matching prescription. |
| G10 | [Garmin support: TrainingPeaks structured workouts](https://support.garmin.com/en-HK/?faq=jnm4aY5LM880wNP6LWm1n8&searchType=noProduct) | Official search-indexed text describes partner calendar/device sync and unsupported RPE targets; direct open returns a navigation shell. Its 50-step/sync-window guidance is partner-specific, not a universal Cohort limit; recheck live contract/device. |
| G11 | [API Brand Guidelines](https://developer.garmin.com/brand-guidelines/api-brand-guidelines/) | Public page identifies attribution requirements for displays/exports/derived data. Exact current assets/rules must be reviewed before live UI acceptance. |
| G12 | [Public template agreement, Rev. B](https://developerportal.garmin.com/sites/default/files/Garmin%20Connect%20Developer%20Program%20Agreement.pdf) | Sections 4.5, 15: consent/privacy/withdrawal and approved authorisation; section 10: template has no licence payment, reserves future fees and excess-volume charges. This is a public template, not Cohort's executed or verified current Starter contract. |

Older root `/training-api/`, `/activity-api/`, `/program-faq/` links return 404;
current pages use `/enterprise/`. The public Business landing and Personal landing
returned no readable body through retrieval. The support page also has the indexed-text/direct-shell limit recorded in G10.
Some FIT wrapper pages return navigation
only; G7/G9 are their actual public article content. This is a visibility limit,
not authority to scrape private Garmin Connect services. No third-party access-pause
rumour or unofficial API library is used as current Garmin authority.

## Contract readiness by required route

| Requirement | Supported route / established fact | Must obtain before live implementation |
|---|---|---|
| Account connection/consent | Business OAuth 2.0 (G4); explicit consent for both directions (G2/G3). | Authorisation/token/refresh/revoke URLs; app type/PKCE requirements, exact scopes, stable user identity and revocation events, state/error semantics. Do not guess from old OAuth 1 examples. |
| Deliver and schedule | Training API → Connect calendar → sync → compatible workout device (G2). | Create/update/delete/schedule contracts, timezone/date rules, workout and schedule identifiers, title/step limits, rate limits, test/production entitlements and delivery acknowledgement meaning. |
| Timed work/recovery repeats | Public FIT indexed atomic/repeat structure (G7); map in MAPPING. | Exact Training JSON repeat/duration representation; device repeat-count/step limits and actual rendering. |
| Pace and numerical HR | Public FIT speed/custom HR ranges (G7/G8). | JSON target units/scales/precision and device display/alert support. No BPM percentage/zone substitution. |
| Activity return | Activity API future push for proposed Starter route (G1/G3). | Callback authentication, permissions, stable activity/user identifiers, payload types, retries/order/ack timeouts, partial/update/delete semantics, retention and any FIT retrieval URLs. Never assume generic ping/pull is available to Starter. |
| Reliable association | Provider activity identity must be distinct from workout/schedule identity. FIT trainingFile can reference a workout file; presence/preservation is unproved (G8/G9). | Whether Training workout/schedule ID or client reference survives in Activity JSON/FIT, uniqueness, file reference mapping and behavior across watch models, rescheduling and repeats. No guaranteed end-to-end correlation has been verified. |
| Devices/testing/production | Workout-capable devices, sync and actual record/save required (G2/G3). Public tools/sample/auto-verification described (G3). | Test-user cap, environment, endpoint verification, activation/review process and enabled APIs in Cohort's app. API availability on new devices is not universal workout-feature support. |

## Exact founder actions (not performed)

1. **Status and responsible account:** confirm whether a Garmin Connect Developer
   Program application/app already exists, its owner, status and enabled Training
   and Activity permissions. Retain a sanitised dated approval/status receipt; never
   paste tokens/passwords. A submitted application is not approval. Choose the
   accountable individual/business identity; G4 does not prove incorporation is
   required. An ordinary Garmin Connect consumer account alone proves no API grant.
2. **If access is absent:** use G5 personally for Business Starter, describing the
   approximately three-athlete private alpha, personalised running delivery and
   completed-activity return. Confirm capacity covers the alpha. Personal own-data
   API does not cover the listed Training requirement (G1); do not choose it as a
   substitute. No Enterprise purchase is established as necessary.
3. **Contract capture:** after legitimate portal access, obtain permitted technical
   specifications for the unresolved rows above and the current applicable agreement,
   fees/volume limits, privacy/withdrawal/deletion and branding obligations. Review
   the actual acceptance/production requirements. G12's no-payment template clause
   is verified only for that template; no current price, free-tier promise, payment
   obligation, Connect+ requirement or Enterprise quote is verified for Cohort.
   Do not copy confidential portal material into a public repository.
4. **Tester hardware:** supply exact founder watch model and firmware, paired Garmin
   Connect platform/version, intended running profile and HR source. Verify that
   model's official manual supports custom structured run workouts, timed repeats,
   pace/BPM range guidance, calendar sync and activity recording. Then perform an
   authorised test. No watch model, purchase or sensor is assumed by this audit.
5. **Later operational authority:** approve a bounded build, then separately enable
   app callback/redirect configuration, secure server credentials, scoped hosted
   changes and consenting tester connection/device test. Supply real approved workout
   content or keep any test explicitly synthetic. An access application grants none
   of these release operations automatically.
