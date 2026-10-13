# Comando per riprendere SIGILLUM

Riprendi SIGILLUM fino alla preparazione della release pubblicabile. Lavora in questa unica chat, usa le autorizzazioni già date nel loro ambito e procedi concretamente senza chiedermi continuamente «prosegui». Prima completa la lettura dei sorgenti e delle loro interazioni; poi correggi solo difetti dimostrati e collauda la candidata.

## 1. Recupera subito il punto di ripresa persistente

Repository app: https://github.com/MARCELLOORIZIO/sigillum-hcv

Ramo documentale: `audit/source-map-build157-20261013`.

Leggi TUTTI questi file nella cartella `docs/sigillum-audit-20261013/`: `HANDOFF.md`, `ARCHITECTURE.md`, `FILE_INVENTORY.md`, `VERIFICATION_PIPELINE.md`, `DEPLOYMENT_STATE.md`, `OPEN_ISSUES.md`, `TEST_MATRIX.md`, `NEXT_CHAT_COMMAND.md`. Decomprimi e consulta `SOURCE_INDEX.json.gz`, che contiene hash, import, canali/metodi nativi e riferimenti API. `build_audit_checkpoint.py` ricostruisce l'indice da snapshot e inventari: non è un patcher dell'app.

Recupera anche il mio documento aggiornato `Testo incollato(8)(1).txt` se disponibile. Non usare una versione precedente al suo posto. I percorsi scratch possono sparire: il repository e i file aggiornati sono il punto di ripresa, non una dichiarazione di memoria permanente del modello.

## 2. Base app corretta: la 157 contiene già PHOTO

Il documento utente identifica la base della build 157 nel commit `f7023853bcdfce927fd760357fe427e9d92ad34b`, ramo `experiment/photo-framing-context-guard-20261010`. Preserva il modello PHOTO MobileNetV3 e gli altri modelli V2/V3 già presenti. PHOTO è attualmente diagnostico (`DIAGNOSTIC_ONLY`), non un input decisivo diretto della policy foto; la parità indipendente su iPhone resta da verificare.

La candidata basata su `fe52264622aa0b08cc61b525efc5bac7761e53be` era stata scelta erroneamente ed è SUPERATA. I suoi 852 test e la compilazione iOS senza firma non certificano la 157. Non ripartire da quella candidata e non chiedermi di nuovo quale commit identifica la 157. PR app #139 è una vecchia bozza: il confronto con f702 contiene workflow/documentazione, non nuove correzioni a lib/iOS/asset. Ricontrolla i riferimenti remoti prima di usarli.

## 3. Leggi davvero i file prima delle modifiche

Sono indicizzati 1.359 file: 1.186 app e 173 backend, con 883 relazioni statiche. Alla consegna sono stati letti integralmente 90 file app e 38 backend; CommercialGate è parziale. Questo NON significa che tutti i file siano stati letti. Completa i file `indexed-only` e gli intervalli mancanti, separando sorgenti attivi, Lab, legacy, test, configurazione, documenti, asset e dipendenze vendorizzate. Un import non dimostra esecuzione nell'edizione User e un asset binario non si legge come codice.

Ricostruisci e documenta: account/dispositivo/KYC/Apple billing; camera e probe HFR; geometria e fusione scena; PHOTO/V2/V3; watermark/GPS/hash/firma RSA/catena; vault cifrato/outbox; pubblicazione R2 e consenso; import/share/OCR; verifica copie/derivati/testo; confronto manuale; canali Dart–Swift; connector OAuth/MCP; pipeline build. I nuovi gruppi completati e i moduli storici senza call site sono già descritti nei documenti. Aggiorna il registro dopo ogni gruppo; non chiamare «letti» file soltanto indicizzati o output troncati.

## 4. Backend e custodia attuali

Repository: https://github.com/MARCELLOORIZIO/hcv-registry-server

Snapshot documentale esaminato: `7e3bcbd694a75079e605277ce81535f4d9785c54`, ramo `release/reconciled-prelaunch-backend-clean-20260824`. Ultimo deploy Render verificato LIVE: `dep-db6u68ou01pc73bk945g`, commit `349b40cf048e74ef9ad74e91d89c476e16b53280`. PR #49/#50/#51 integrate; ricontrolla eventuali aggiornamenti. HEAD e commit distribuito sono distinti.

Il runtime viene materializzato dai patcher di prestart: il production_server tracciato da solo non è il server effettivo. La copia di audit ha applicato i patcher Python, senza avviare server/DB né eseguire l'installer DB. Non sovrascrivere modifiche locali preesistenti del checkout backend.

R2 privato è la custodia del riferimento tecnico; YouTube/Telegram sono percorsi storici o distribuzione distinta. Non ripristinare YouTube come riferimento primario. Consenso, ownership, binding, AES-GCM, hash e autorizzazione monouso sono controlli separati. Il ritiro revoca accesso e pubblicazione, poi il worker riprova la cancellazione; l'account non viene eliminato finché la rimozione non è confermata. Render LIVE non equivale a `PRODUCTION_LIVE=true`: non cambiare quel flag solo per presentare la release come pronta.

## 5. Primo difetto confermato da correggere

In RegistryVerifyPage il mapper di provenienza controlla `contains('verificat')` prima della negazione: «Non verificata» può diventare «Verificata». Il dettaglio provenienza restituisce inoltre il messaggio positivo senza distinguere stato negativo o indisponibilità. Dopo la lettura prepara una correzione mirata e una regressione significativa che verifichi testo/stato/dettaglio nelle quattro lingue, includendo errore di rete. Non toccare firma, hash o soglie per correggere la presentazione.

Le altre osservazioni sono in OPEN_ISSUES: cleanup fallback dei derivati, etichetta di salvataggio sottotitoli, traduzioni incomplete, controllo PHOTO nell'IPA, migrazione accounts potenzialmente non raggiungibile e differenze di allineamento video app/backend. Riproduci e verifica i call site prima di trasformare queste osservazioni in patch.

## 6. Completa tutte le richieste prodotto e i collaudi aperti

- Verifica separatamente provenienza, integrità, derivazione e scena. Verde per esito positivo, giallo per ambiguo/non conclusivo, rosso per negativo: non manipolare soglie per ottenere un colore.
- Riproduci originale identico segnalato rosso, copie Messenger non alterate, foto lievemente modificate e derivato sottotitolato autorizzato. Usa byte/hash/versione/esito/motivo e percorso decisionale. Conformità percettiva non significa identità SHA dell'intero file.
- Verifica il divieto di taglio iniziale nei video e l'ancoraggio ai primi secondi; non trasferire questa policy alle foto. Non confondere la pre-verifica OCR con l'analisi completa.
- Collauda sottotitoli fino alla fine dell'audio, avanzamento/interruzione/pulsanti visibili, assenza di sovrapposizioni, tre azioni coerenti e derivazione autorizzata vincolata all'originale.
- Collauda GPS/autorizzazioni, selezione foto iOS senza ricompressione indebita, anteprime, Salva in Foto e condivisione con upload del riferimento esatto. Chiarisci originale sul dispositivo e riferimento protetto sul server.
- Collauda verifica del testo copiato dai social con relativo HCV-ID/certificato.
- Verifica 7 giorni/30 giorni/anno, acquisto, ripristino, scadenza e account ownership Apple. L'annuale riuscito riferito non convalida tutti i piani. Il confronto manuale visivo o auditivo deve offrire accesso all'acquisto e ritorno alla funzione.
- Ricontrolla tutte le pagine interne/esterne, comunicazione della catena attuale e quattro lingue IT/EN/ES/RU. Verifica con fonti ufficiali i riferimenti normativi prima di dichiararli corretti; nessuna promessa assoluta sulla credibilità della scena.

## 7. Originali e connector: evita un nuovo loop OAuth

Plugin privato SIGILLUM: `dev-6acde43d474081919427d5f55bc97b5a@openai-curated-remote`. Nell'altra chat l'utente ha riferito ricezione di HCV-D8FF76496D424CA5 e HCV-255DEE0995364F99: entrambi mostrano uno schermo, quindi non provano un falso positivo. Questa chat non ha ispezionato indipendentemente quei byte. Servono esiti/log associati e casi segnalati senza schermo.

Al controllo precedente i tool SIGILLUM non erano esposti qui: verifica le capacità realmente disponibili senza simulare chiamate. Non riutilizzare grant scaduti né salvare immagini originali, certificati privati, token o credenziali in Git. Il trasporto connector corrente supporta JPEG/PNG inline fino a 8 MiB; video/foto grandi e collaudo reale completo expiry/revoca/replay restano aperti.

Configurazione OAuth già verificata: client pubblico `sigillum-chatgpt-private`, nessun client secret, S256 PKCE, scope `sigillum:originals:read`; callback esatta `https://chatgpt.com/connector_platform_oauth_redirect`. Email/password dell'account SIGILLUM non sono client ID/secret. Non riaprire la configurazione senza un errore documentato.

## 8. Release: prove da produrre

La base f702 ha CI verdi `38169122649` e `38169119613`; sono prove CI/compilazione, non collaudo iPhone. Il tentativo successivo Codemagic era fallito con `CODEMAGIC_TOKEN_MISSING_NO_BUILD`: nessuna nuova IPA/TestFlight è stata confermata. Non inventare credenziali o dichiarare caricata una build senza evidenza.

Dopo le correzioni dimostrate crea la nuova candidata da f702, esegui test pertinenti e controlli richiesti, verifica inclusione/hash dell'asset PHOTO e runtime TensorFlowLite iOS fissato, compila l'IPA firmata e associa sourceCommit, CFBundleVersion, attestazione e build realmente visibile su TestFlight. Poi collauda su iPhone foto/video/social/sottotitoli/acquisti e prepara i passaggi App Store. Non dichiarare pubblicata o pronta un'app che ha soltanto test verdi.

Il nuovo screenshot mostrava «You've hit your usage limit»: riguarda ChatGPT, non SIGILLUM. I messaggi «No such file or directory» riguardavano allegati locali mancanti; non dimostrano un errore dell'app e non autorizzano a inventare il contenuto delle immagini.

Procedi con azioni concrete e aggiornamenti brevi. Mantieni i documenti versionati, distingui sempre implementato/testato/distribuito/collaudato e termina con modifiche effettive, prove e impedimenti specifici.
