# Audit reale corpus PHOTO 1.502 immagini — 2026-10-13

Il corpus originale e' stato recuperato da Library /SIGILLUM/SIGILLUM_build127_training_corpus_final_v1.zip, non dal solo manifesto GitHub.

- SHA-256 archivio: 1d12bf594cec61616ef2b922915a31263f693b31d959ccea39914643b4c995f8 (coincide col manifesto).
- Immagini aperte e hash individuali verificati contro manifest.csv: 1.502 / 1.502; errori 0.
- Classi storiche: SCREEN_MONITOR 479; SCREEN_PHONE 65; SCREEN_TABLET 36; REALITY_PAPER 203; REALITY_ROOM 199; REALITY_OBJECT 334; REALITY_OUTDOOR 186.
- Rilievo campionario visivo (48 per classe): in SCREEN_MONITOR ci sono sia schermi ravvicinati sia monitor riconoscibili come oggetti; in REALITY_ROOM sono presenti anche schermi in una scena fisica.
- Pertanto 580 etichette SCREEN e 922 etichette REALITY NON sono ground truth della nuova distinzione «monitor-oggetto» vs «ricattura indistinguibile dalla scena».
- E' stata generata una coda CSV di revisione delle 1.502 immagini e sette tavole di campionamento con seed riproducibile 157. Le nuove etichette sono intenzionalmente UNDETERMINED finche' non giudicate indipendentemente.
- Richiesta policy: monitor oggetto riconoscibile => scena fisica reale, nessun allarme di ricattura full-frame su quel solo fatto; full-frame senza forma/contesto del monitor => possibile ricattura, richiede corroborazione fisica per rischio alto; segnali in conflitto => non conclusivo. Provenienza e integrita' su assi indipendenti.
- Dati foto sul campo: HCV-320B7BFFF0AB41CC (due monitor fisici), HCV-A0320ADC213C460C (primo piano display, V2=0.9437/V3 veto), HCV-6FD2FFCD6CDF438C (geometria contraddittoria), HCV-56D4B022D9C34A77 (reality balcone).
- Non esistono ancora 1.502 etichette indipendenti nuove, dunque NON e' possibile attestare recall/specificita' o autorizzare promozione in produzione.
- Nessuna modifica a modelli, soglie, decisioni, build 157 o TestFlight eseguita in questo audit.
