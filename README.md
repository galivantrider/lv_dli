<div align="center">

# LSA Onboarding Gate

### HabotConnect Data Compliance

<p>A Flutter mobile experience for verifying LSA records with traceable lineage and fail-closed compliance controls.</p>

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13%2B-0175C2?logo=dart&logoColor=white)
![License](https://img.shields.io/badge/license-private-lightgrey)

</div>

---

## Overview

**LSA Onboarding Gate** is a focused verification screen for validating lineage before an LSA record is submitted. It combines a polished, gradient-based mobile UI with an HTTP compliance request and strict failure handling.

The experience is intentionally fail-closed: incomplete lineage never reaches the network, and an uncertain API response quarantines the record instead of treating it as successful.

## Highlights

- Clean login/signup-inspired visual design with a purple gradient and elevated form card
- Predecessor, LSA, and parent-consent fields
- Real-time status banner: **Idle**, **Processing**, **Success**, or **Data Quarantined**
- Mandatory trace and logic-hash metadata on every outbound request
- Immediate orphan-data blocking through `LineageException`
- Timeout, server-error, malformed-response, and null-status protection
- Volatile form data purge and submission lock after compliance failure
- Consent-field hesitation logging after five seconds of inactivity
- Injectable HTTP client for deterministic widget testing

## User Flow

```text
Idle
  |
  v
Validate predecessor lineage ── missing ──> Quarantined (no network call)
  |
  v
Processing ── valid response ──> Success
  |
  └────────── timeout / 500 / null status ──> Quarantined + form purge + lock
```

## API Contract

The screen sends a `POST` request to:

```text
https://api.habotconnect.com/v1/compliance/verify
```

### Required headers

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `x-trace-id` | `8f3d1b2a-4c9e-4a11-b8d2-9901ef23a011` |
| `x-logic-hash` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

### Request body

```json
{
  "predecessor_id": "PRED-9982-XYZ",
  "lsa_id": "LSA-7049",
  "parent_consent_code": "PCC-2026-9901",
  "timestamp_utc": "2026-08-07T11:30:00Z"
}
```

> The endpoint is a mock integration target. A real device may show the quarantine state when the host is unavailable or returns an invalid response.

## Compliance Rules

| Scenario | Result |
| --- | --- |
| Valid predecessor and consent data | Request is sent with mandatory metadata; status becomes **Success** when the response is valid |
| Empty or missing `predecessor_id` | Request is blocked immediately; status becomes **Data Quarantined** |
| HTTP 500, timeout, invalid JSON, or `{ "status": null }` | Volatile fields are cleared, submission is locked, and status becomes **Data Quarantined – Compliance Failure** |

## UI Friction Logging

If the parent consent field receives focus and the user does not type or submit for five seconds, the app emits:

```text
[UI_FRICTION_LOG] Timestamp: <UTC timestamp> | Field: parent_consent_code | Hesitation Duration: 5.0s
```

## Project Structure

```text
lib/
  main.dart             # App shell, verification screen, API flow, and state handling
test/
  widget_test.dart      # Valid, orphan-data, and failed-response coverage
```

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `^3.13.1`
- An Android emulator, iOS simulator, or connected device

### Run locally

```bash
flutter pub get
flutter run
```

### Validate

```bash
flutter analyze
flutter test
```

## Design Direction

The interface takes visual inspiration from the [flutter_login_signup](https://github.com/TheAlphamerc/flutter_login_signup) project: expressive gradients, a centered rounded card, soft input surfaces, and a clear primary action. The content and interaction model are purpose-built for LSA data compliance.

## License

This project is private and intended for authorized HabotConnect development use only.
