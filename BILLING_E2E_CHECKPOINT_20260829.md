# SIGILLUM billing E2E checkpoint — 2026-08-29

This file is the recovery point for billing work before returning to reality-vs-monitor detection.

## Objective

A new Creator must be able to create and verify a SIGILLUM account, buy exactly one Apple subscription, obtain Creator access only after server verification, cancel renewal without losing already-paid access, restore the same still-active Apple subscription only to its owning SIGILLUM account, lose access after expiry, and buy again afterwards. The custom paywall must never display a numeric price whose currency cannot be proven consistent with the current App Store storefront.

## Invariants

1. No local purchase return grants entitlement.
2. Entitlement is granted only after Apple authenticity + SIGILLUM backend status `active` or `grace`.
3. One Apple `originalTransactionId` has one durable SIGILLUM account owner.
4. A current Apple subscription owned by another SIGILLUM account is terminal for that account: do not transfer it and do not open a new payment sheet that would merely change the foreign plan.
5. A stale unfinished transaction that is no longer a current entitlement may be finished after the backend authenticates it, so it cannot block a genuinely new purchase.
6. Cancellation disables renewal but does not revoke access before Apple expiry.
7. Restore never resurrects an expired/revoked subscription.
8. On iOS, a numeric paywall price is shown only from an Apple-backed storefront/product snapshot whose currencies agree; otherwise show `App Store` and let the Apple sheet show the exact localized amount.

## Saved checkpoints

### App — purchase/account core before final price guard

Branch: `checkpoint/billing-core-purchase-account-20260829`

Commit: `1af02175d0c2de96a0b76dd12a08bc45e56f35ef`

Contains the verified StoreKit terminal-state handling and stale foreign unfinished-transaction cleanup without the final storefront-country currency cross-check.

### Backend — weekly product + stale recovery + durable Apple ownership

Repository: `MARCELLOORIZIO/hcv-registry-server`

Branch: `checkpoint/billing-backend-ownership-20260829`

Commit: `b820ea80613dd9f9ef245e0557122417340f2624`

Render production branch must remain `release/reconciled-prelaunch-backend-clean-20260824` at or after this commit unless a later validated backend billing commit supersedes it.

## Test precondition: what “new user from zero” means

A new SIGILLUM email alone is not a clean Apple subscription test. The Apple subscription belongs to the Sandbox/Apple account and one subscription group can have only one current subscription chain. Therefore a clean E2E new-user test requires both:

- a new SIGILLUM account, for example a new Gmail `+sigillumtestN` alias; and
- a Sandbox Apple Account with no current SIGILLUM subscription chain, preferably a separate Gmail `+appletestN` alias.

If the iPhone purchase sheet still shows the old Sandbox Apple Account, the test is not a clean new-user Apple test. A weekly/monthly/annual selection may be interpreted by Apple as a plan change on the existing subscription and must not be linked to the new SIGILLUM account.

## E2E acceptance sequence

1. Create new SIGILLUM account and verify email.
2. Complete Stripe Identity test-success flow and refresh KYC status.
3. Paywall: no stale/wrong numeric currency. Correct localized Apple price or neutral `App Store` only.
4. Buy weekly plan with a clean Sandbox Apple Account.
5. Apple sheet shows localized price; after confirmation backend verifies and Creator becomes active.
6. Sign out/reinstall/sign in to the same SIGILLUM account; restore the still-active purchase. Access returns without a second charge.
7. Cancel renewal in Apple subscription management. Access remains active until Apple expiry.
8. After Sandbox expiry, reopen SIGILLUM: paywall returns and restore does not grant access.
9. Buy again: new verified active entitlement restores Creator access.
10. Cross-account negative test: sign in to a different SIGILLUM account while the first Apple subscription is still current. It must not inherit or purchase over that foreign subscription; backend returns `APPLE_SUBSCRIPTION_ALREADY_LINKED` before a payment sheet is opened.

## Reality-vs-monitor handoff

Once the acceptance sequence above is green on the final TestFlight build, billing is frozen. Subsequent work resumes from the HCV reality-vs-monitor pipeline (temporal/optical/geometry/ML/fusion) and billing code is not changed unless a new reproducible billing defect is demonstrated.
