# Pipeline e significato degli esiti

## Foto create in app

`CameraPage.takePhoto`: GPS se richiesto → probe HFR nativo isolato → contesto geometrico/sensori passivo → ripristino autofocus/zoom/flash → mini-video tecnico di 1,5 s → scatto → analisi ottica/V2/V3/framing/PHOTO sui byte prima del watermark → policy multi-evidenza → watermark → SHA-256 dei byte pubblicati → fingerprint → claims/certificato/provenienza/attestazione → verifica locale → hcvpack → journal/outbox → seal cifrato → retry Registry.

**L'originale certificato è il file finalizzato e pubblicato con watermark**, non il file grezzo del sensore. I segnali scena sono ricavati prima del watermark; l'hash d'integrità riguarda il file finale. Conservare questa distinzione nelle prove identico/alterato/Messenger.

`HCVPhotoSemanticFramingInference` usa asset PHOTO presente nella base 157, input NCHW [1,3,160,160], orientamento applicato, resize average e RGB/255. Verifica SHA asset e forme tensori. Tre classi: PHYSICAL_SURFACE_OR_SCENE, DISPLAY_IN_REAL_SCENE, POSSIBLE_FULL_FRAME_DISPLAY. Output diagnostico: sceneFraming UNKNOWN, decisionRole DIAGNOSTIC_ONLY, parità iOS non indipendentemente verificata. `resolvePhoto` non riceve direttamente tale predizione.

Il vecchio `HCVPhotoSemanticFramingRunner` è un executor separato subordinato a verifiedModelManifest; non confonderlo con l'inference realmente richiamata dalla camera.

V2 usa letterbox 224 e RGB 0–255; V3 residual usa letterbox 96 e RGB/255, tre uscite hard/clean/hardNegativeReality. Sono preprocessing diversi per modelli diversi. V3 può porre veto al solo forte V2 foto; non annulla un HFR forte valido né influisce sul video.

La policy PHOTO controlla framing geometrico corroborato e comparabilità HFR. Un HFR non comparabile resta diagnostico. I conflitti, la persistenza e i segnali fisici sono controllati da regole specifiche; assenza di evidenza display non è prova positiva che la scena sia fisica. La diagnostica semantica non va resa decisiva cambiando soglie senza validazione.

## Video

Il probe HFR precede REC; la camera effettiva dopo startVideoRecording è nuovamente attestata. Si confrontano lente, zoom, field of view e aspect ratio: una sostituzione fisica o mismatch impedisce trasferire il probe al video come evidenza comparabile.

Alla fine si attende stabilità del contenitore, si processano watermark, hash, fingerprint, claims e firma. La policy di confronto iniziale richiede primi secondi: non estendere questa regola alle foto. Il controllo del taglio iniziale richiede anche lettura completa del matching e prova reale.

I sottotitoli usano Apple Speech e retry sulle code mancanti; l'output è una copia derivata separata, cifrata nel vault. La pubblicazione del derivato richiede firma che vincola parent SHA, captioned SHA, subtitle SHA e pack SHA. Non sostituire il riferimento primario.

## Verifica online

1. Identificazione HCV-ID (nome/OCR/testo o input), recupero certificato Registry.
2. Verifica certificato RSA, contenuto, identity, provenance e software attestation disponibili. I record legacy hanno uno stato distinto.
3. Hash dei byte candidati: uguaglianza esatta col certificato prima di ogni tolleranza percettiva.
4. Quando diverso: verifica riferimento moderno R2 e fingerprint firmato/compare dettagli; i fallback legacy non devono bypassare un esito moderno non conclusivo.
5. Foto: backend confronta candidate con riferimento materializzato protetto e restituisce CONFORMING/MODIFIED/INCONCLUSIVE, senza restituire l'originale pubblico.
6. Video: confronto visivo, temporale e audio; divergenza audio impedisce trasferire automaticamente l'esito positivo visivo. Il derivato sottotitoli autorizzato ha un percorso distinto.
7. Esporre separatamente provenienza, integrità, scena e derivazione. Una copia non legata positivamente al riferimento non eredita automaticamente la scena dell'originale firmato.

## Colori e interpretazione

La validità dell'hash non prova la credibilità della scena. Una foto può essere l'originale certificato di uno schermo realmente presente. Un rischio display non prova una modifica del file.

RegistryVerifyPage distingue severe issue (invalid, media not verified, unproven derivative, official modified) e intermediate issue (rete, inconclusive, riferimento assente/errore, screen warning). Il colore complessivo non sostituisce la lettura delle singole assi; la classificazione segnalata dall'utente va ricondotta all'esatta stringa result e alle claims della build interessata.
