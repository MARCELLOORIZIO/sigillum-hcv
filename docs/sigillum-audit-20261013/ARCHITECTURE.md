# Architettura SIGILLUM verificata sui sorgenti

Snapshot e copertura: vedere `FILE_INVENTORY.md`. Gli import statici non provano l'attivazione di un ramo. Le note distinguono comportamento letto da validazione reale.

## Edizione e build

`lib/main.dart` inizializza Flutter/MediaKit, elimina temporanei del vault e seleziona `CommercialGate` per User o `HomePage` per Lab. L'edizione deriva dal define `SIGILLUM_EDITION`. Un import raggiungibile dalla radice può quindi appartenere solo alla navigazione Lab.

Codemagic compila sorgenti già materializzati e impedisce modifiche a lib/test/iOS durante build. `pin_tflite_ios_runtime_20260826.sh` modifica il podspec della dipendenza esterna tflite_flutter, fissando TensorFlowLite 2.17.0. I vecchi `apply_*` dell'app non devono essere rilanciati indiscriminatamente: non sono la pipeline TestFlight corrente.

## Componenti e interazioni

| Flusso | File principali | Invariante verificato nel codice |
| --- | --- | --- |
| Account/dispositivo | commercial_gate, commercial_account_service, hcv_auth_service, hcv_identity; server materializzato | Sessione account separata da firma/identità del dispositivo; proof RSA con purpose e signedAt |
| Abbonamento | commercial_billing_service, CommercialGate; AppDelegate hcv.storekit2; app_store_billing e patcher server | StoreKit fornisce evidenza; il backend verifica e associa l'originalTransactionId all'account |
| KYC | commercial_account_service/hcv_registry_service; Stripe Identity nel backend | KYC e abbonamento Apple sono controlli distinti |
| Acquisizione | camera_page, camera plugin, AppDelegate cameraProbe | Il probe HFR rilascia e ricostruisce la camera Flutter; geometria effettiva registrata |
| Scena | temporal_frequency_probe, live_screen_probe e parti, screen_replay_analyzer, ML V2/V3, multi_evidence_display_policy | Provenienza e integrità non sono sostituite dal rischio display |
| PHOTO semantico | photo_semantic_framing_inference/contract; asset PHOTO | Diagnostica firmata; non input decisivo diretto di resolvePhoto |
| Certificazione | hcv_engine, capture_provenance, provenance_chain, keystore_signer, software_attestation | Hash sui byte finalizzati, evento vincolato a sessione/dispositivo; payload RSA canonico |
| Custodia locale | secure_media_vault, secure_preview_service, SecureOriginalsPage | AES-GCM a blocchi, SHA/size dopo decifratura; account e creator controllati |
| Certificato online | registry_service, server materializzato, certificate_account_binding, registry_provenance_v2 | Outbox persistente; conferma leggibilità Registry prima di eliminare la coda |
| Riferimento privato | verified_originals_publish_service; verified_originals_production, primary_reference_provider/lifecycle/manifest | R2 privato, ciphertext e binding; riferimento primario esatto separato dal derivato sottotitoli |
| Verifica copie | RegistryVerifyPage, fingerprint V3, photo_detail_compare backend | Hash esatto precede confronto percettivo; tre esiti distinti CONFORMING/MODIFIED/INCONCLUSIVE |
| Confronto umano | ManualReferenceComparePage, VerifiedReferenceViewerPage, publisher | Richiede abbonamento active; materializza temporaneamente, elimina all'uscita |
| Import iOS | ShareViewController, SceneDelegate hcv.intent, CommercialGate, HCVImportRouterPage | Condivisione di JPEG/PNG conserva i byte quando disponibili; percorso persistito e ack dopo navigazione |
| Connector | connector_runtime/remote/oauth, dispatcher/service/bridge/grant_adapter | OAuth non concede automaticamente accesso agli originali; delega separata monouso |

## Canali nativi

| Canale | Dart → Swift | File nativo |
| --- | --- | --- |
| hcv.keystore | getPublicKey, sign; get/set/deleteSecret | SceneDelegate: RSA 2048, Keychain AfterFirstUnlockThisDeviceOnly |
| hcv.intent | getSharedPath, ackSharedPath; callback onSharedPath | SceneDelegate, App Group group.com.sigillum.hcv |
| hcv.media | pickOriginalPhoto, saveToPhotos, validateImageForOcr, extractVideoFrame, transcribeVideo, burnSubtitles | SceneDelegate: Photos/AVFoundation/Speech |
| hcv.cameraProbe | snapshot/configure/lock/apply/restore camera, captureTemporalFrequencyNative | AppDelegate: sessione AVFoundation isolata |
| hcv.photoLibrary | saveMedia | AppDelegate: autorizzazione addOnly, crea asset da file |
| hcv.storekit2 | currentEntitlements, currentStorefrontCurrency, localizedProductPrices; storefrontChanged | AppDelegate: transazioni verified, JWS al backend |

La chiamata `localizedProductPrices` esiste anche nel canale hcv.media: la presenza di due gestori non equivale ad avere due flussi d'acquisto attivi.

## Backend realmente avviato

`npm start` esegue `prestart` e poi `production_server.js`. La versione tracciata (700 righe) è trasformata dai patcher in una versione di 1.743 righe nella copia di audit. Il server così prodotto importa billing, configurazione, firma canonica, binding certificato, provenance v2, verified originals e connector runtime. Il dispatcher chiama prima connector, poi verified originals, poi le route account/Registry.

`precheck` riproduce i patcher Python ma omette il passo DB `node tool/ensure_device_enrollment_schema.js`, presente in prestart. La materializzazione di audit non ha eseguito quel passo. `server.js`, auth_api/auth_proxy/kyc_proxy e better-sqlite3 appartengono alla superficie legacy: la loro sola presenza non li rende backend LIVE.

## Custodia e R2

Il vault cifra media e hcvpack, conserva certificato/outbox e journal dei seal pendenti. Non cancella il plaintext prima del commit sicuro. L'apertura è vincolata a creator e hash del soggetto account; la materializzazione controlla GCM, lunghezza e SHA e viene eliminata dopo uso.

Il provider R2 deriva una chiave con HKDF dal master key, salt e binding canonico; AES-256-GCM usa AAD con HCV-ID, ruolo, hash original/pack/manifest/reference, media type e object ID. Il key object è opaco. `activeR2Reference` richiede job committed, consenso ACTIVE, ownership/provenance e manifest verificato. Non espone un URL pubblico al media privato.

YouTube/Telegram sono ricerca o percorsi precedenti: non ripristinarli come custodia primaria. La decisione documentata è R2 per il riferimento tecnico e distribuzione social distinta.

Il lifecycle PG distingue PENDING, UPLOADING, RETRY_WAIT, COMMITTED, DELETE_PENDING, DELETED e FAILED_PERMANENT. Un indice unico impedisce autorità simultanee per HCV-ID/ruolo; il claim upload è atomico e le code batch usano SKIP LOCKED. Il commit confronta ogni campo del receipt col binding. Le cancellazioni richiedono conferma HEAD/404 prima di DELETED; retry con backoff. La lettura completa di verified_originals_production conferma che initSchema avvia il timer di takedown, normalmente ogni cinque minuti: riprova ritiri registrati e job DELETE_PENDING. Questo non dimostra un worker autonomo equivalente per recuperare gli upload senza un nuovo invio dall'app.

Il consenso viene ricontrollato con lock prima della registrazione della pubblicazione. Il ritiro aggiorna consenso WITHDRAWN e pubblicazione REVOKED nella transazione, quindi tenta la cancellazione provider. withdrawAllForAccount sospende la cancellazione dell'account con 503 finché il takedown non è COMPLETED. I derivati sottotitoli hanno ruolo, hash sorgente, hash sottotitoli e firma binding distinti; il riferimento R2 primario conserva i byte finali originali, mentre il percorso storico YouTube crea una transcodifica.

SecureOriginalsPage richiede diritti confermati per Salva/Condividi, chiama ensureReference prima dell'esportazione e cancella il materiale temporaneo in finally. Il viewer privato assume la custodia del proprio temporaneo. VerifiedOriginalsPage separa ricerca pubblica da apertura del riferimento che richiede subscriptionStatus active. Il profilo considera anche grace come abbonamento attivo nell'etichetta; le route riferimento richiedono active: distinguere rappresentazione e diritto effettivo.

## Ottica e OCR: lettura completata il 13 ottobre

Il probe temporale usa profili di righe in nove regioni, frequenze spaziali/temporali, timestamp, esposizione e lock attestati. Il recupero HFR non basta senza comparabilità geometrica e corroborazioni previste. fullFrameReality non viene promosso dal semplice silenzio del probe. La geometria passiva confronta movimento locale, piano proiettivo e residui; il helper planare storico non deve essere scambiato per il modello proiettivo attivo.

ScreenReplayAnalyzer campiona segmenti limitati di video; per foto usa indizi statici e griglia/lattice, non inventa flicker temporale da una singola immagine. Il discriminator lattice protegge dall'uso ingenuo di pattern periodici come prova di display. Nessuna soglia modificata.

L'OCR foto combina immagine intera, ritagli superiori ingranditi e maschera gialla; la selezione usa consenso di letture. Le varianti esadecimali C/0, B/8, E/6 sono costruite per recovery solo dopo assenza Registry della prima lettura. QuickHcvMediaGatePage prova due frame iniziali 0,2 e 0,8 secondi con fallback mirato prima di restituire nessun HCV-ID; questa pre-verifica non è il confronto integrità completo.

`hcv_crypto.dart` contiene Ed25519 con nuova chiave per chiamata, ma la ricerca dei call site in lib non trova utilizzatori del simbolo HCVCrypto. La certificazione camera usa RSA persistente: non sostituirla con l'helper storico. Anche HCVContextFreeDisplayPolicy, HCVDisplayFinalPolicy e il comparator foto Dart hanno definizioni ma nessun call site in lib nella base esaminata; la policy attiva camera è multi-evidenza e il dettaglio foto moderno è lato backend.

## Connector e delega

OAuth authorization code + S256, client pubblico predefinito, callback esatta. Flow 5 minuti, code 60 secondi, access token 30 minuti; nessun refresh token implementato. Le credenziali in DB sono hash, legate ad account/dispositivo/client/issuer/resource/scope.

MCP remoto usa SDK 1.32.1, Streamable HTTP stateless, Host/Origin/TLS espliciti, richieste massimo 16 KiB e deadline 10 secondi. Il dispatcher ricontrolla autenticazione anche dopo letture lente.

`sigillum_request_original_audit` crea PENDING limitato agli HCV-ID; il proprietario approva separatamente. Il grant adapter riserva atomicamente la lettura PRIMA di decifrare, controlla account/dispositivo/consenso/riferimento/abbonamento prima e dopo, e registra esiti. Il service riusa activeR2Reference/streamR2Reference, senza seconda logica di decifratura. Il trasporto corrente inline supporta solo JPEG/PNG fino a 8 MiB.
