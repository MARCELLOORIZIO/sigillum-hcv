# SIGILLUM / HCV - Patent Invention Map

Draft for patent counsel review. This document is not legal advice. Its purpose is to separate the technical invention areas before a prior-art search and formal claim drafting.

## Strategic Thesis

SIGILLUM should not be described merely as an app for certifying photos or videos.

The stronger technical thesis is:

> SIGILLUM certifies the verifiable identity of digital content across capture, transformation, distribution and verification, rather than certifying only a static original file.

This distinction matters because a conventional cryptographic hash proves that a specific file is unchanged. SIGILLUM also attempts to preserve verification when a file is renamed, recompressed, converted or shared through social platforms.

## Possible Patent Family

### 1. Trusted Mobile Acquisition And Certification

Possible title:

> Method and system for trusted acquisition and certification of digital multimedia content using a mobile device.

Technical scope:

- capturing photo, video or text through a mobile device;
- generating an HCV-ID;
- calculating a cryptographic hash of the captured content;
- binding the content to a signed certificate;
- associating the certificate with a technical creator identity;
- applying a visible HCV mark or embedded verification reference;
- registering the certificate in an online registry;
- enabling later verification by file, HCVPACK or HCV-ID.

Potential inventive contribution:

The coordinated technical process that binds acquisition, device identity, cryptographic proof, visible marking and registry verification at creation time.

Risk:

Generic "certify a photo with hash and signature" may be anticipated by prior art. The claim must focus on the specific coordinated flow and technical interactions.

Priority:

High. This is the foundation patent.

### 2. Screen Replay Detection During Certified Capture

Possible title:

> Method for detecting screen replay in camera-captured content using optical, temporal and machine-learning signals.

Technical scope:

- determining whether a camera is capturing a real scene or a displayed/replayed scene;
- analyzing flicker, refresh bands, moire, grid patterns, stable exposure, local temporal variation and geometric cues;
- using an ML classifier trained on screen and reality categories;
- combining optical and ML analyses into a screen-replay risk output;
- writing the result into the certificate and/or watermark;
- distinguishing analyzed, not analyzed and inconclusive states.

Potential inventive contribution:

The joint use of live preview signals, captured-frame signals and ML classification to produce a technical warning about indirect capture from a monitor, phone, tablet, projection or other display.

Possible markets:

- KYC and onboarding;
- digital identity;
- banking antifraud;
- e-government;
- remote signing;
- media provenance.

Risk:

Computer vision for display detection exists. The strongest claim may be the integration into a certified capture pipeline, not screen detection alone.

Priority:

High. This is one of the most technically distinctive areas.

### 3. Persistent Content Identity Across File Transformations

Possible title:

> Method for maintaining verifiable identity of digital content across transformations of the underlying file.

Technical scope:

- assigning a persistent HCV-ID to content;
- linking HCV-ID, signed certificate, cryptographic hash and perceptual fingerprint;
- verifying content after social-media recompression, renaming, metadata stripping or container changes;
- using perceptual/video-frame fingerprint matching to connect a transformed file to an original certificate;
- reporting different verification states, such as exact hash match, social fingerprint match, ID valid/media not verified, or tampered.

Potential inventive contribution:

The system does not rely only on the original binary file hash. It uses a layered identity model that can survive common file transformations while still detecting mismatch or substitution.

Strategic importance:

Very high. This is likely the conceptual core of HCV.

Risk:

Perceptual hashing and content fingerprinting are known. Claims must focus on the use of those fingerprints in a signed certificate and registry-based identity framework.

Priority:

Very high.

### 4. HCV-ID As Persistent Verification Identifier

Possible title:

> Persistent verification identifier for certified digital content.

Technical scope:

- generating an HCV-ID during or immediately after capture;
- embedding or associating the HCV-ID with media, certificate, watermark, registry record and HCVPACK;
- using the HCV-ID to retrieve the certificate from a remote registry;
- allowing verification even when the content file has been renamed;
- preventing misleading verification when an HCV-ID is copied onto different content.

Potential inventive contribution:

The HCV-ID functions as a verification anchor across multiple representations of the same content, rather than being merely a UUID, hash or watermark.

Risk:

An identifier alone is probably weak as a patent. It becomes stronger as part of a technical verification method.

Priority:

Medium-high. Possibly claim as part of patents 1 and 3 rather than standalone first.

### 5. Multi-Signal Trust Score

Possible title:

> Method for computing a trust score for digital content using cryptographic, device, sensor, registry and machine-learning verification signals.

Technical scope:

- collecting verification signals: hash, signature, registry, device key, identity status, sensor coherence, GPS, timestamp, ML risk, screen replay risk, social fingerprint;
- weighting the signals;
- producing a trust level or score;
- explaining the reason for the trust level;
- distinguishing verified content from content with warnings or incomplete analysis.

Potential inventive contribution:

A technical trust score derived from heterogeneous device, cryptographic and forensic signals.

Risk:

Scoring systems can look abstract or administrative unless tied to specific technical measurements and verification outputs.

Priority:

Medium. Develop more implementation detail before filing.

### 6. Distributed HCV Ecosystem

Possible title:

> Distributed system for creation, registry, recovery and validation of certified digital content.

Technical scope:

- mobile creator app;
- registry server;
- validator app/API;
- HCVPACK offline package;
- browser or social verification flow;
- identity binding;
- certificate retrieval by HCV-ID;
- local and online verification paths.

Potential inventive contribution:

The architecture enables both offline package verification and online registry recovery, while preserving content identity and creator binding.

Risk:

Distributed verification systems and certificate registries are known. Claims should focus on specific HCV content-identity and transformation-resilient verification mechanics.

Priority:

Medium.

## Protection Matrix

| Asset | Possible protection |
| --- | --- |
| SIGILLUM name | Trademark |
| HCV name | Trademark |
| HCV protocol | Patent, standard, license |
| Mobile certified capture flow | Patent |
| Screen replay detection | Patent |
| Transformation-resilient content identity | Patent |
| HCV-ID | Patent component, protocol element, trademark/standard |
| Registry architecture | Patent or trade secret |
| AI models and thresholds | Trade secret |
| Source code | Copyright and trade secret |
| Dataset | Trade secret/database rights where applicable |
| App UI and brand | Copyright, design, trademark |

## Recommended Filing Strategy

### Phase 1 - Prior-Art Search

Search at least:

- EPO Espacenet;
- WIPO Patentscope;
- USPTO;
- Google Patents;
- academic literature on perceptual hashing, camera replay detection, media provenance and C2PA.

Search topics:

- certified mobile capture;
- trusted camera acquisition;
- content provenance;
- perceptual hash verification after social recompression;
- screen replay detection;
- liveness detection through camera sensors;
- signed media certificate registry;
- robust content identifier.

### Phase 2 - Provisional Technical Disclosure

Prepare one technical disclosure with:

- problem;
- architecture;
- flow diagrams;
- HCV-ID lifecycle;
- certificate structure;
- screen-replay analysis;
- social fingerprint verification;
- registry verification;
- failure states;
- example screenshots and certificate JSON fields.

### Phase 3 - Decide Patent Split

Recommended initial split:

1. Core certified acquisition and registry method.
2. Persistent content identity across transformations.
3. Screen replay detection inside certified capture.

Trust score and distributed ecosystem can follow once the implementation is more mature.

## Important Caution

Avoid public disclosure of the most detailed technical mechanisms before filing, especially:

- exact thresholds;
- dataset construction;
- fingerprint comparison tolerances;
- anti-replay fusion logic;
- registry trust protocol details;
- private model behavior.

Public demos can describe the benefit, but the technical mechanism should remain controlled until counsel confirms filing strategy.

## Short Counsel Brief

SIGILLUM / HCV is a mobile and server system for creating and verifying digital content provenance. It captures media, generates a persistent HCV-ID, creates a signed certificate bound to technical creator identity, records or retrieves the certificate through a registry, detects possible screen replay using optical and ML signals, and verifies content even after common file transformations such as social-media recompression or renaming. The desired patent strategy is to protect not merely a file hash, but a persistent, verifiable identity of content across capture, distribution and later validation.
