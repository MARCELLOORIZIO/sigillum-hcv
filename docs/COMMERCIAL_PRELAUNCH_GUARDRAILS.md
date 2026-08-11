# SIGILLUM commercial prelaunch guardrails

## Immutable capture and certification boundary

Commercialization work must not alter the behavior, thresholds, evidence generation, capture flow semantics, hashes, signatures, watermarks, HCVPACK structure, text integrity logic, monitor detection, geometric/parallax analysis, flash challenge, photo classifier, or video classifier that are already validated in the current working build.

Commercial work is limited to layers outside that boundary:

- onboarding and access gating;
- account UX;
- email verification and password recovery;
- legal/privacy presentation and consent records;
- subscription entitlement checks;
- identity/account binding;
- authenticated Registry transport;
- server persistence, database, rate limiting, observability, backups and abuse protection;
- public verification access.

## Product access model

Public content verification remains accessible without KYC. Content creation/certification requires an authenticated, verified creator account and an active entitlement.

## Production architecture target

- stateless Node.js API;
- managed PostgreSQL for certificates, accounts, sessions, identity bindings and consent records;
- no production SQLite dependency;
- public certificate reads remain available without login;
- certificate writes require authenticated creator entitlement and server-side signature validation;
- existing HCV certificate payload is not changed by commercial gating;
- transactional email uses an HTTPS email API, not app-side or Gmail SMTP;
- production secrets remain server-side environment variables.

## Current commercial branch

`commercial/prelaunch-20260811`
