# SIGILLUM / HCV - Patent Invention Map

Draft for patent counsel review. This document is not legal advice. Its purpose is to separate the technical invention areas before a prior-art search and formal claim drafting.

## Strategic Thesis

SIGILLUM should not be described merely as an app for certifying photos or videos.

The stronger technical thesis is:

> SIGILLUM certifies the verifiable identity of digital content across capture, transformation, distribution and verification, rather than certifying only a static original file.

This distinction matters because a conventional cryptographic hash proves that a specific file is unchanged. SIGILLUM also attempts to preserve verification when a file is renamed, recompressed, converted or shared through social platforms.

## Market Gap Positioning

SIGILLUM should be positioned around the gap left when standard provenance chains are interrupted.

### Level 1 - Native Provenance Chain

This is the environment where C2PA and similar systems are strongest:

```text
Compatible capture device
  -> signature
  -> metadata
  -> manifest
  -> verification
```

In this scenario, SIGILLUM should not claim that hash, signature, metadata, manifest or registry are new by themselves.

### Level 2 - Degraded / Non-Cooperative Distribution

This is the environment where SIGILLUM should focus:

```text
Original media
  -> WhatsApp / Telegram / Instagram / TikTok
  -> screenshot / crop / recompression / rename / re-upload
  -> manifest lost
  -> metadata lost
  -> exact hash no longer useful
  -> signature no longer directly attached to the media
```

The technical problem becomes different:

> Estimate continuity of content identity after non-cooperative transformations using multiple technical evidences.

This framing is stronger than saying that SIGILLUM replaces C2PA. It says that C2PA works well when the provenance chain remains intact, while SIGILLUM addresses cases where that chain has been broken.

Suggested patent-style phrase:

> Method for estimating continuity of identity of digital content across non-cooperative transformations by integrating multiple technical evidences.

This language is useful because:

- "estimating" reflects that the result may be probabilistic;
- "continuity of identity" avoids claiming simple file equality;
- "non-cooperative transformations" identifies the hard technical environment;
- "multiple technical evidences" avoids reliance on a single fingerprint or identifier.

## HCV Content Identity Layer

For long-term patent and platform strategy, SIGILLUM can be described as an implementation of a broader proposed architecture:

> HCV Content Identity Layer, or HCIL.

This framing is intentionally cautious. It does not assert that a new paradigm has already been proven over the prior art. It proposes an architecture to be tested through prior-art search and technical implementation.

The objective of HCIL is:

> to provide a technical infrastructure for estimating, representing and explaining continuity of identity of digital content through non-cooperative transformations.

Conventional provenance systems often operate through:

```text
Content
  -> hash
  -> signature
  -> metadata
  -> manifest
  -> verification
```

HCIL instead proposes an additional layer:

```text
Content
  -> identity
  -> relationships
  -> evidences
  -> continuity estimate
  -> decision and explanation
```

The key difference is that HCIL is not limited to asking whether a single file is unchanged. It aims to estimate whether multiple files, media instances or derivatives remain technically related to the same source content.

### HCIL Modules

| Module | Role |
| --- | --- |
| HCV Registry | Registry of certified content identities and certificates |
| HCV Matching Engine | Compares transformed media with stored identity evidence |
| HCV Evidence Engine | Collects and fuses heterogeneous technical signals |
| HCV Identity Graph | Represents relationships between source and derived contents |
| HCV Decision Engine | Classifies and explains the verification result |

This modular framing has two advantages:

1. each module can be assessed as a possible inventive nucleus;
2. the platform is not limited to the SIGILLUM mobile app or to photo/video use cases.

Possible future content domains:

- images;
- video;
- audio;
- PDF and documents;
- 3D models;
- CAD files;
- medical files;
- AI-generated content.

### Counsel Question

The main question for patent counsel should be framed at the problem level:

> Is it patentable to provide a method that, in the absence of original metadata, manifest and attached signatures, reconstructs or estimates continuity of identity of digital content by integrating heterogeneous technical evidences and producing a structured representation of relationships between derived contents?

This question forces analysis of the technical problem rather than isolated components such as HCV-ID, fingerprint or registry.

## Three Technical Levels

### Level 1 - Vision

The identity of content should survive common transformations.

This is the product vision, not by itself the patentable mechanism. A patent examiner will likely ask what technical process makes that persistence possible.

### Level 2 - Architecture

The persistent identity is produced by the interaction of multiple technical elements:

```text
HCV-ID
  -> perceptual fingerprint
  -> cryptographic hash
  -> signed certificate
  -> creator/device identity
  -> registry record
  -> trust score and verification decision
```

Each element has a different role:

- the cryptographic hash verifies exact file integrity;
- the perceptual fingerprint supports matching after transformations;
- the HCV-ID anchors retrieval and human-facing verification;
- the signed certificate binds claims to the content identity;
- the registry enables recovery and later validation;
- the trust score combines exact and tolerant evidence.

### Level 3 - Technical Mechanism

The core patent question is how SIGILLUM determines that a transformed media file still corresponds to the certified content.

Candidate technical flow:

```text
Input media
  -> normalization
  -> feature extraction
  -> perceptual fingerprint generation
  -> cryptographic hash generation
  -> certificate signing
  -> registry storage
  -> transformed media input
  -> feature extraction on transformed media
  -> candidate certificate retrieval by HCV-ID or search
  -> exact hash comparison
  -> tolerant fingerprint comparison
  -> multi-signal scoring
  -> verification decision
```

Technical details to define before filing:

- which visual/audio/video features are extracted;
- whether features are frame-based, region-based, temporal, structural or semantic;
- how video frames are sampled;
- how transformations such as crop, resize, recompression, format conversion, screenshot and metadata removal are normalized;
- which distance metrics compare fingerprints;
- which tolerance bands are used for social-media recompression;
- how cryptographic hash evidence and perceptual evidence are weighted;
- how mismatch, partial match, exact match and uncertain states are separated;
- how copied HCV-IDs are detected when the media fingerprint does not support the claimed identity.

This level is the likely heart of the claims. The phrase "persistent identity" should be treated as the result; the above mechanism is what must be claimed.

## Content Identity Graph / Transformation Genealogy

A possible later invention area is not only answering:

> Does this content derive from the certified original?

but also:

> What transformation path did this content follow?

Example:

```text
Original capture
  -> WhatsApp compression
  -> screenshot
  -> crop
  -> TikTok video
  -> extracted frame
  -> second compression
```

If SIGILLUM can infer or record a chain of transformations, the system becomes a content genealogy engine rather than only a verification engine.

Possible technical approach:

- store a root HCV identity;
- store derived fingerprints for transformed versions;
- classify transformation types such as recompression, crop, resize, screenshot, frame extraction or container conversion;
- link each derived media instance to a parent identity with a confidence score;
- represent the result as a transformation graph rather than a single yes/no match.

Patent relevance:

This may be a separate future filing if the implementation becomes concrete. It should be investigated in prior art together with content provenance, perceptual hashing and media lineage systems.

### Content Identity Graph As Technical Object

The genealogy should be framed as a data structure, not merely a feature.

Possible object name:

> Content Identity Graph

or:

> Content Lineage Model

Each node may represent a media instance or derivative:

- cryptographic hash, if available;
- perceptual fingerprint;
- HCV-ID or linked source HCV-ID;
- timestamp or observation time;
- media type and container;
- detected transformation type;
- confidence value;
- source certificate or registry reference;
- screen-replay or authenticity risk indicators.

Each edge may represent a derivation hypothesis:

- exact copy;
- social recompression;
- crop;
- resize;
- screenshot;
- frame extraction;
- re-upload;
- screen replay;
- unknown transformation.

This changes the core question from:

> Is this file original?

to:

> Are these multiple files technically related to the same source content, and with what confidence?

This is a stronger technical and commercial positioning than simple verification.

Potential technical output:

```text
Source content HCV-12345678
  -> derivative A: social recompression, confidence 0.97
  -> derivative B: crop from A, confidence 0.83
  -> derivative C: screenshot of source, confidence 0.72
  -> derivative D: unrelated content with copied HCV-ID, confidence 0.08
```

## Technical Problem / Solution / Effect Mapping

Each candidate claim should be tied to a concrete technical problem and technical effect.

| Technical problem | SIGILLUM solution | Technical effect |
| --- | --- | --- |
| Loss of identity after recompression, resize, rename or format conversion | HCV-ID combined with perceptual fingerprint and registry retrieval | Recognition of the same content after common transformations |
| Exact file hash fails after social-media processing | Layered verification using cryptographic hash for exact match and perceptual fingerprint for tolerant match | Distinguishes unchanged files from transformed but related files |
| HCV-ID may be copied onto unrelated media | Compare claimed HCV-ID certificate against transformed media fingerprint | Detects ID valid/media not verified or substitution states |
| Metadata can be stripped or manipulated | Signed certificate and registry record independent from file metadata | Preserves verifiable technical claims even if metadata is removed |
| Content provenance is uncertain | Device/creator key binding and certificate signature | Improves technical attribution of content origin |
| Camera may capture a screen rather than a real scene | Optical, temporal and ML screen-replay analysis during or after capture | Reduces false treatment of screen replays as direct original captures |
| Social platforms alter media containers and names | Verification by HCV-ID, HCVPACK, registry and fingerprint rather than file name | Enables verification after uncontrolled distribution |
| Verification result may be opaque | Multi-signal explanation including hash, fingerprint, registry and risk signals | Produces an auditable technical reason for the decision |

## Inventive Core Questions

Before claim drafting, counsel should identify the element or combination that gives SIGILLUM its non-obvious technical character.

Key question:

> Which feature, if removed, would make SIGILLUM lose its distinctive technical identity?

Candidates:

- HCV-ID as the persistent anchor;
- tolerant media matching against a signed certificate;
- combined cryptographic hash plus perceptual fingerprint;
- registry recovery by HCV-ID plus anti-substitution checks;
- multi-signal trust score;
- screen replay detection inside the certified capture flow;
- the coordinated combination of all elements.

Preliminary view:

The strongest inventive core is likely not the HCV-ID alone. It is more likely the combination of:

1. persistent HCV-ID;
2. signed certificate;
3. exact hash evidence;
4. tolerant perceptual fingerprint evidence;
5. registry retrieval;
6. decision logic that separates exact match, transformed match, uncertain match and substitution.

This should be treated as the primary claim candidate for the persistent-content-identity patent.

## Essential And Optional Features

This distinction helps build independent and dependent claims.

| Component | Role | Claim relevance |
| --- | --- | --- |
| HCV-ID | Persistent retrieval and identity anchor | Essential for HCV identity claims |
| Signed certificate | Binds claims to content identity | Essential |
| Cryptographic hash | Exact integrity verification | Essential for exact-match branch |
| Perceptual fingerprint | Tolerant identity matching after transformations | Essential for transformation-resilient claims |
| Registry | Online certificate recovery and later validation | Essential if claim requires remote recovery; optional for offline HCVPACK claims |
| HCVPACK | Offline package containing media and certificate | Optional or separate dependent claim |
| Visible watermark/HCV mark | Human-facing reference and deterrence | Optional |
| Creator/device identity | Attribution and technical origin binding | Essential for creator-attribution claims; optional for pure content-identity claims |
| GPS | Contextual trust signal | Optional |
| Accelerometer/gyroscope | Sensor coherence and liveness support | Optional |
| ML screen replay classifier | Screen risk analysis | Optional for core identity; essential for screen-replay patent |
| Optical screen replay analysis | Screen risk analysis | Optional for core identity; essential for screen-replay patent |
| Trust score | Aggregated decision output | Optional for core identity; essential for trust-score patent |
| Explanation report | Human-readable/auditable verification reason | Optional now; possible future claim family |

## Transformation Genealogy Variants

The genealogy concept should be separated into distinct technical levels.

### Variant A - Derivation Recognition

The system determines whether media B derives from certified media A.

Example output:

```text
B derives from A with 98.7% fingerprint confidence.
```

This is the closest extension of the current verification flow.

### Variant B - Transformation Sequence Reconstruction

The system attempts to reconstruct a chain:

```text
A -> recompressed image -> screenshot -> crop -> video frame -> new compressed image
```

This is more ambitious and requires transformation classification.

### Variant C - Probabilistic Lineage Graph

The system does not assert a single certain sequence. It builds a graph of possible derivations with confidence levels.

Example:

```text
Root HCV-ID
  -> Derivative 1: WhatsApp recompression, confidence 0.94
  -> Derivative 2: crop from Derivative 1, confidence 0.81
  -> Derivative 3: frame extraction from video, confidence 0.76
```

Patent relevance:

These variants should not be mixed too early. Variant A may be claimable sooner; Variants B and C likely require more implementation and prior-art search.

## Verifiable Explanation Of Results

A future module may produce not only a positive or negative result, but an auditable explanation.

Example output:

```text
HCV-ID: present
Certificate: recovered from registry
Signature: valid
Exact hash: not matching
Perceptual fingerprint match: 98.7%
Geometric consistency: high
Screen replay risk: low
Transformation hypothesis: social recompression
Derivation probability: 99.2%
Decision: verified transformed derivative
```

Technical value:

- improves transparency of automated decisions;
- supports forensic or evidentiary review;
- separates exact integrity from transformed-content identity;
- helps detect mismatched HCV-ID overlays or copied identifiers.

Patent relevance:

The explanation should be tied to computed technical signals, not merely presented as a user-interface summary.

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

Prior-art worksheet:

| Nucleus | Known areas to compare | Possible differentiator to test |
| --- | --- | --- |
| Certified mobile capture | trusted camera apps, signed image capture, media provenance | combined HCV-ID, device identity, watermark, certificate and registry flow |
| Screen replay detection | liveness detection, display detection, moire/flicker analysis, anti-spoofing | live preview plus captured-media analysis inside a signed capture certificate |
| Persistent content identity | perceptual hashing, robust video fingerprinting, content ID systems | signed identity that combines exact hash and tolerant social fingerprint with registry retrieval |
| HCV-ID | UUIDs, content IDs, watermarks, digital object identifiers | ID used as retrieval anchor plus anti-substitution verification against media fingerprint |
| Trust score | fraud scoring, provenance scoring, liveness scores | score derived from cryptographic, sensor, ML, registry and social-fingerprint evidence |
| Transformation genealogy | media lineage, provenance graphs, C2PA-like manifests | graph of derived media identities after uncontrolled social transformations |

For each nucleus, counsel should identify:

1. features already disclosed in prior art;
2. features that are merely business or presentation logic;
3. features that produce a technical effect;
4. combinations that may be non-obvious;
5. fallback claim positions if broad claims are rejected.

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

## Technical Roadmap To Increase Patent Value

The following roadmap prioritizes engineering work that can strengthen future patent claims.

### 0. Define HCIL Module Boundaries

Goal:

Separate the mobile app from the broader content identity infrastructure.

Work items:

- define interfaces between Registry, Matching Engine, Evidence Engine, Identity Graph and Decision Engine;
- define which data each module receives and produces;
- define the minimum evidence package needed to create a content identity;
- define how HCIL can support media beyond photo and video;
- document which parts are implemented today and which are future modules.

Patent value:

This makes it easier to identify whether the invention is a system, method, data structure, scoring engine, graph model or a combination of these.

### 1. Resilient Matching Engine

Goal:

Define which features remain stable across recompression, crop, resize, format conversion, screenshots and social-media distribution.

Work items:

- build test sets for WhatsApp, Telegram, Instagram, TikTok and screenshot transformations;
- measure feature stability after each transformation;
- compare frame-level, region-level, temporal and perceptual descriptors;
- define distance metrics and tolerances;
- separate exact match, transformed match, partial match and mismatch.

Patent value:

This creates concrete technical material for claims around non-cooperative transformation matching.

### 2. Evidence Model

Goal:

Define how independent technical signals are combined into a decision.

Signals:

- exact hash;
- perceptual fingerprint;
- HCV-ID;
- registry certificate;
- watermark or visible ID;
- screen-replay indicators;
- device/creator identity;
- metadata, when available;
- timestamp and sensor coherence, when available.

Outputs:

- exact verified;
- transformed derivative verified;
- ID valid/media not verified;
- uncertain;
- tampered or substituted.

Patent value:

The invention becomes a technical decision system rather than a single fingerprint lookup.

### 3. Content Identity Graph

Goal:

Represent relationships among multiple media instances derived from the same source.

Work items:

- define node schema;
- define edge schema;
- store derivation confidence;
- classify transformation type;
- maintain root HCV identity;
- support multiple derivatives and branching paths;
- produce an auditable graph or lineage report.

Patent value:

This may be the highest-value future patent direction because it frames SIGILLUM as reconstructing relationships between contents, not merely verifying one file.

### 4. C2PA-Compatible Extension Strategy

Goal:

Position SIGILLUM as complementary to standard provenance systems.

Work items:

- map SIGILLUM certificate fields to C2PA concepts;
- define how SIGILLUM behaves when a C2PA manifest exists;
- define how SIGILLUM behaves when the manifest is missing;
- use HCV identity and fingerprint matching as a recovery layer for broken provenance chains.

Patent and market value:

This avoids claiming to replace established standards and instead positions SIGILLUM as an extension for degraded, non-cooperative distribution environments.

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

SIGILLUM / HCV is a mobile and server system that may be positioned as an implementation of a broader HCV Content Identity Layer. The system creates and verifies digital content identity evidence. It captures media, generates an HCV-ID, creates a signed certificate bound to technical creator identity, records or retrieves the certificate through a registry, detects possible screen replay using optical and ML signals, and attempts to verify content even after non-cooperative transformations such as social-media recompression, renaming, crop, screenshot or re-upload. The desired patent strategy is not to claim hash, signature or registry in isolation, but to evaluate whether a method or infrastructure for estimating, representing and explaining continuity of content identity across broken provenance chains can be protected.
