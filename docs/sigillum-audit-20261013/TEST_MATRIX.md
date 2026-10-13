# Prove ed evidenze

Non equiparare implementazione, test sintetico, CI, compilazione iOS, dispositivo reale e produzione.

| Componente/caso | Evidenza disponibile | Stato che si può affermare |
| --- | --- | --- |
| Snapshot/dependency index | 1.186 file app +173 backend, hash/static imports, ledger esplicito | Inventario completo, revisione semantica parziale |
| Materializzazione backend | Patcher Python precheck su copia isolata; server1743 righe | Ricostruzione codice runtime senza esecuzione DB/server |
| Base157 f702 | CI38169122649 Verified Originals app e38169119613 PHOTO unsigned iOS: success osservato nella sessione | Test/compilazione CI della base; nessuna equivalenza automatica a prova iPhone |
| Candidatafe522 | Run38372626893:852 test, audit, build iOS no-codesign success | Solo vecchia base; NON certifica157 o nuova release |
| Connector OAuth/HTTPS | 77 test locali precedenti, quattro suite CI verdi su32e7d7d e bac064e8 | Sintetico/CI, incluso client SDK e fixture AES/SQL |
| Deploy/edge | Render LIVE349b40cf; precedenti health/discovery200, auth challenge401, Origin403 | Distribuzione e confine HTTP verificati, non tutte le funzioni |
| Originali prioritari | Resoconto utente dalla conversazione audit: due schermi visibili | Ricezione/visione riferita; non ispezione indipendente eseguita qui |
| Expiry/revoca/replay reali | Test sintetici presenti; nessun risultato reale completo documentato | Da collaudare senza riutilizzare grant scaduti |
| PHOTO preprocessing | Input/hash/resize/classes letti; marker parity iOS non verificata | Implementazione presente, validazione dispositivo pendente |
| PHOTO test/parità | Quattro file test e PARITY.json letti: hash/TFL3, isolamento, 6pixel resize, 5seed conversione | Copertura sintetica limitata; nessun nuovo test runtime lanciato |
| Dettaglio foto | Test Dart noise/overlay/edit locale/tono/input errato; backend4fixture sintetiche letti | Non costituisce collaudo Messenger reale |
| Fingerprint audio/video | Audio max15s, visivo V3 max120frame a2fps, ancora iniziale4frame | Bounds accertati nel sorgente; confronto percettivo non prova integrità byte completa |
| Copia identica | Hash esatto precede matching nel codice | Comportamento letto; riproduzione dei reclami pendente |
| Copia Messenger/crop/alterata | Comparator backend e fingerprint diversi da SHA | Prove di corpus e percorso decisionale da collegare |
| Sottotitoli | Retry Speech/timeline/burn-in/vault/binding presenti | iPhone e audio fino alla fine da verificare |
| Premium manuale | Paywall e ritorno alla feature letti | Test acquisto/restore/expiry reale pendente |
| GPS/Photos/share | Bridge nativi e richieste permesso letti | Prove dispositivo nelle condizioni segnalate pendenti |

La ricognizione non ha lanciato nuovi test funzionali: nessun codice applicativo è stato modificato. Il controllo necessario per questa modifica documentale è consistenza di snapshot, riferimenti, inventario, copertura e file diff del commit. I test funzionali verranno scelti in base alle successive patch dimostrate, non per validare una dichiarazione generica di app completa.
