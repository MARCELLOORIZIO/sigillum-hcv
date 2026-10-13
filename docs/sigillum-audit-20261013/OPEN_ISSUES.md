# Problemi aperti e prove necessarie

| Priorità | Problema/stato | Evidenza e prossimo controllo |
| --- | --- | --- |
| P0 processo | Revisione completa incompleta | Inventario totale e lettura parziale non devono essere scambiati per piena comprensione. Continuare dai file indexed-only/partial prima delle modifiche |
| P0 release | Candidata scelta dalla base sbagliata | Errore accertato: fe522 invece della base 157 f702. Vecchia candidata SUPERATA; mantenere il PHOTO nella futura candidata |
| P1 collaudo | IPA/ultima build TestFlight reale | Documento utente identifica157, CI f702 presente; manca qui prova archivio firmato/CFBundleVersion/sourceCommit e runtime device |
| P1 scena | Falsi positivi e semantica divergente | I due casi prioritari descritti dall'utente mostrano schermi; non provano falsi positivi. Servono esiti e percorso decisionale, oltre ai casi senza schermo segnalati |
| P1 integrità | Identico rosso / alterazioni leggere / Messenger | Separare SHA identico, scena e matching percettivo. Riprodurre sulla base157 con hash e risultati separati, senza cambiare soglie per il colore |
| P1 modello | Parità PHOTO sul dispositivo | Sorgente dichiara DIAGNOSTIC_ONLY e NOT_YET_INDEPENDENTLY_VERIFIED_ON_IOS. Compilazione e corpus preliminare non sono prova iPhone |
| P1 connector | Accettazione reale completa | Ricezione in altra chat riferita dall'utente; expiry/revoca/replay reali non documentati come completati. Strumenti plugin assenti qui al controllo precedente |
| P1 media | Video/foto grandi nel connector | Solo JPEG/PNG inline fino a8 MiB; trasporto protetto video non implementato |
| P1 sottotitoli | Interruzione/UI/derivazione | Retry Speech e binding derivato presenti nel codice; richieste prove reali fine audio, comandi visibili e classificazione copia autorizzata |
| P1 abbonamenti | 7gg/30gg/anno, restore/scadenza | Prodotti e reconcile presenti; acquisto annuale riuscito riferito. TestFlight/iPhone dei tre piani non completato da questa ricognizione |
| P2 traduzioni | Quattro lingue | Esistono blocchi letterali italiani nel recent-account picker di CommercialGate e dettagli delle assi Registry. Presenza di mappe tradotte non dimostra copertura totale |
| P2 build proof | Controllo PHOTO nell'IPA | Asset incluso nel pubspec e inference; lista cmp dello script storico copre solo V1/V2/V3. Verifica futura anche PHOTO prima della release |
| P2 custodia | Cleanup fallback creator | wipeCreatorVault non elenca derivati sottotitoli come wipeAccountVault. Chiamato solo nel fallback cancellazione senza accountId; da riprodurre prima di modificarlo |
| P2 UI | Messaggio salvataggio derivato | saveContentToGallery riconosce captioned dal nome _sottotitolato; materializeCaptionedVideo usa nome hcvId/purpose. Verificare etichetta effettiva, non dedurre modifica del media |
| P2 continuità | Documenti backend precedenti incoerenti | HANDOFF/OPEN_ISSUES vecchi dicono ancora PR51 non distribuita; DEPLOYMENT_STATE ha appendici più recenti. Questa cartella esplicita stato e correzione candidata |
| P2 lifecycle | Refresh OAuth/retention | Token30min senza refresh; UX di riconnessione e gestione righe flow/token/rate da valutare prima distribuzione ampia |

GPS, Foto, testo social, anteprime e consensi: implementazioni parzialmente lette; non dichiarare risolti tutti i reclami solo dalla presenza del codice. Policy video sui primi secondi da provare separatamente dalle foto. Riferimenti normativi/commerciali richiedono revisione documentale dedicata; nessun parere legale conclusivo prodotto qui.

Nessuna delle osservazioni nuove sul codice è stata corretta durante la ricognizione. Le osservazioni riproducibili e i test di regressione devono precedere patch e nuova candidata.
