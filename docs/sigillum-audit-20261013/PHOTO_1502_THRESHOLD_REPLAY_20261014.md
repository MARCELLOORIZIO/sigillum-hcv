# Replay esaustivo V3 sulle 1502 foto — 2026-10-14

File input: `/SIGILLUM/SIGILLUM_build127_training_corpus_final_v1.zip` verificato SHA-256 `1d12bf594cec61616ef2b922915a31263f693b31d959ccea39914643b4c995f8`; CSV di output PyTorch V3 con 1502 predizioni clean/hard: `v3_1502_exploratory_scores.csv` (allegato pacchetto audit in conversazione).

Questo replay applica **tutte le soglie possibili** alla probabilità max(clean,hard) già calcolata per le 1502 foto, con ground truth *storico* SCREEN-family/REALITY-family. Non è un replay del V2, HFR, optical, PHOTO TFLite o della nuova tassonomia monitor-oggetto vs full-frame.

| V3 threshold | SCREEN storici persi | REALITY storiche segnalate schermo | Errori |\n| --- | ---: | ---: | ---: |\n| 0.20 | 16 | 163 | 179 |\n| 0.35 | 24 | 55 | 79 |\n| 0.50 | 43 | 20 | 63 |\n| 0.65 | 75 | 12 | 87 |\n| 0.80 | 122 | 4 | 126 |\n| 0.90 | 215 | 2 | 217 |\n
La migliore soglia in-sample calcolata è `0.49863` con **62 errori** (42 SCREEN persi, 20 falsi SCREEN storici). È una misura di diagnostica, non una proposta di soglia di produzione: ottimizzare sul training corpus causerebbe leakage. NESSUNA soglia unica V3 produce 2 errori sul corpus.

**Blocco verificabile:** l'archivio JPEG non contiene per tutti i soggetti le predizioni V2 effettive, sequenze HFR temporali acquisibili da dispositivo, foto PHOTO TFLite con equivalenza su iPhone, e annotazioni indipendenti di oggetto-monitor riconoscibile. Non è corretto dichiarare 1500/1502, confrontare «regole nuove vs vecchie» come se le prove mancanti fossero disponibili, né distribuire nuove soglie. Recuperare i dati mancanti e rieseguire un holdout fisico prima di integrare qualsiasi policy. I benchmark storici BUILD127 riportano 28/28 su holdout specifico e il codice Flutter usa V3 solo come veto: benchmark e comportamento on-device non sono equivalenti.
