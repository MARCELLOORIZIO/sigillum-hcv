# SIGILLUM — punto di ripresa verificato, 13 ottobre 2026

**Stato: revisione dei sorgenti in corso. Non è una dichiarazione di app pronta alla pubblicazione.**

## Ordine utente e base corretta

L'utente richiede prima la lettura dei file e delle loro interazioni, poi correzioni dimostrate, regressioni e release. La documentazione deve essere persistente e consentire di riprendere nella stessa chat senza ricominciare da assunzioni errate.

Il documento aggiornato fornito dall'utente identifica la build 157 con il sorgente `f7023853bcdfce927fd760357fe427e9d92ad34b`, ramo `experiment/photo-framing-context-guard-20261010`. Il modello PHOTO MobileNetV3 è presente in questa base. Non chiedere di nuovo quale commit corrisponde alla 157.

L'assistente aveva scelto erroneamente `fe52264622aa0b08cc61b525efc5bac7761e53be`, escludendo il PHOTO già presente nella 157. Questa candidata è **SUPERATA**. I suoi 852 test e la compilazione iOS senza firma non validano la 157. Non usare `release/testflight-candidate-20261013` per la release finale.

## Cosa è stato fatto nella ricognizione

- Snapshot immutabili: app f702385; backend 7e3bcbd. Inventario di 1.186 file app e 173 backend, con hash, import, riferimenti a canali/metodi nativi/API e categoria.
- Il registro `FILE_INVENTORY.md` distingue lettura completa, parziale e sola indicizzazione. Il numero dei file indicizzati NON è il numero dei file compresi semanticamente.
- Il backend è stato materializzato esclusivamente in una copia temporanea attraverso i patcher Python di `precheck`. Il codice prodotto è diverso dal solo `production_server.js` tracciato. Non è stato eseguito il passo DB `ensure_device_enrollment_schema.js` né avviato il server.
- Ricostruiti i collegamenti principali di certificazione, firma nativa, modelli PHOTO/V2/V3, scena, archivio cifrato, sottoscrizione, pubblicazione R2, confronto e connector OAuth/MCP. Restano moduli grandi e test da leggere integralmente; gli intervalli sono espliciti nell'inventario.
- Nessuna modifica funzionale dell'app, nessuna soglia cambiata, nessun nuovo deploy durante questa ricognizione.

Ulteriore lettura completa: provenance chain/canonicalizzazione, testo, fingerprint audio/social/spaziale/V3, comparator dettagli foto app/backend, binding/provenance/firma del Registry, App Store billing/config e lifecycle/provider R2. Sono stati letti i quattro test PHOTO e il test dettaglio foto Dart/backend. L'indice comprende anche import package:sigillum_iphone dai test ai sorgenti.

## Stato remoto ricontrollato

PR backend #49 e #50 integrate. PR #51 integrata al merge `a678bdfd976b554e38679160efba6b08896a6ef6`. PR app #139 aperta, in bozza; HEAD `cd8caf39b92114e27d78451bdd48af4ee316f5af`.

Il confronto API GitHub f702385...cd8caf39 contiene soltanto due nuovi workflow e `docs/RELEASE_CANDIDATE_20261013.md`; nessuna modifica a `lib`, iOS o asset. Quel documento descrive la candidata superata: questa nota ne corregge esplicitamente il riferimento.

Render: deploy `dep-db6u68ou01pc73bk945g` LIVE a `349b40cf048e74ef9ad74e91d89c476e16b53280`, ricontrollato attraverso list_deploys. HEAD backend 7e3bcbd è documentale e distinto dal commit LIVE. Vedere `DEPLOYMENT_STATE.md`.

## Originali e limiti della prova

L'utente ha completato la registrazione del plugin privato. Nell'altra conversazione ha riferito ricezione/visualizzazione di entrambi gli originali prioritari e ha riportato l'analisi visiva: entrambi mostrano uno schermo. Questo è un resoconto ricevuto dall'utente, non una nuova lettura dei byte eseguita qui. Non dimostra un falso positivo del rilevatore o la correttezza del percorso decisionale.

Gli strumenti SIGILLUM non sono esposti in questa conversazione al controllo effettuato. Non simulare chiamate al plugin, non aggirare il consenso e non riutilizzare una delega scaduta. Nel repository non salvare immagini originali, certificati privati, credenziali, token o dati personali.

## Prossimo lavoro

1. Continuare la lettura degli intervalli mancanti e dei moduli di confronto/provenienza/ottica indicati nell'inventario. Aggiornare il registro a ogni gruppo esaminato.
2. Leggere i test specifici e collegarli ai comportamenti; conservare la distinzione tra test sintetici, CI, iPhone e produzione.
3. Per ogni difetto segnalato ricostruire input, versione e decisione prima di correggere. Nessuna regolazione delle soglie per ottenere un colore desiderato.
4. Solo dopo questa revisione creare la candidata dalla base f702385 e dalle correzioni dimostrate, preservando il PHOTO diagnostico. Verificare IPA/commit/CFBundleVersion/attestazione e poi prove reali.

Le autorizzazioni utente già ricevute rimangono valide nel loro ambito. Il lavoro corrente è documentale e reversibile. Le modifiche locali non tracciate nel checkout backend preesistente non sono state incorporate né sovrascritte.

## Documenti da leggere alla ripresa

[ARCHITECTURE.md](ARCHITECTURE.md), [FILE_INVENTORY.md](FILE_INVENTORY.md), [VERIFICATION_PIPELINE.md](VERIFICATION_PIPELINE.md), [DEPLOYMENT_STATE.md](DEPLOYMENT_STATE.md), [OPEN_ISSUES.md](OPEN_ISSUES.md), [TEST_MATRIX.md](TEST_MATRIX.md). L'indice completo è [SOURCE_INDEX.json.gz](SOURCE_INDEX.json.gz). Nessuna memoria del modello sostituisce questi riferimenti versionati.
