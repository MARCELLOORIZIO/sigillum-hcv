# Versioni e distribuzione — 13 ottobre 2026

| Oggetto | Stato verificato | Limite |
| --- | --- | --- |
| Base app indicata per build 157 | f7023853bcdfce927fd760357fe427e9d92ad34b | Identificazione nel documento utente; archivio firmato non recuperato qui |
| PR139 | OPEN, DRAFT, HEAD cd8caf39b92114e27d78451bdd48af4ee316f5af | Successivi 4 commit: solo 2 workflow e documento candidata |
| Vecchia candidata | release/testflight-candidate-20261013, HEAD 3715245368e7f2fae2fbf648012ebaa3cb971bfd | SUPERATA; base fe522 priva del PHOTO della 157 |
| Richiesta Codemagic via workflow | Run 38372978802 fallita CODEMAGIC_TOKEN_MISSING_NO_BUILD | Non ha creato build API; nessuna IPA/TestFlight confermata |
| PR49 backend | MERGED cfd195c18ad83f651c7648178501c1b74d72027d | Audit delegato |
| PR50 backend | MERGED b83cfcd213de1e594829fcd2c563fa7d1c50aa62 | Start audit precompilato |
| PR51 backend | MERGED a678bdfd976b554e38679160efba6b08896a6ef6 | OAuth/MCP remoto |
| HEAD backend release | 7e3bcbd694a75079e605277ce81535f4d9785c54 | Ultimo commit documentale, distinto dal LIVE |
| Deploy Render ricontrollato | dep-db6u68ou01pc73bk945g LIVE, commit 349b40cf048e74ef9ad74e91d89c476e16b53280 | Stato deploy non equivale a collaudo completo di ogni funzione |

Servizio `srv-d9u3inbm8hqs73eee5g0`, workspace `tea-d81i50reo5us738dgcs0`, regione Frankfurt. Auto-deploy disattivato; build npm install, start npm start con prestart.

## Build e attestazione

pubspec della base f702 riporta 1.0.0+149. Lo script TestFlight seleziona max(source build, latest TestFlight + 1), passa lo stesso valore al define SIGILLUM_BUILD_NUMBER e controlla CFBundleVersion archiviato. Pertanto 149 nel sorgente non smentisce automaticamente la 157 indicata dall'utente.

Il nuovo asset PHOTO pesa 3.816.772 byte; SHA-256 fb66682d213e15f2418ab802c3d00af375b57646e94c50fd0d18a8c8422c567f. Il proof script storico verifica esplicitamente gli asset V1/V2/V3, ma non aggiunge PHOTO all'elenco cmp nell'archivio: estendere quel controllo nella futura candidata dopo la revisione, senza rimuovere il modello.

## Configurazione connector non segreta

- Endpoint: https://sigillum-registry-production.onrender.com/connector/mcp
- Client pubblico: sigillum-chatgpt-private. Nessun client secret; auth token endpoint none, PKCE S256.
- Redirect autorizzato attuale: https://chatgpt.com/connector_platform_oauth_redirect (soltanto questo).
- La vecchia callback /connector/oauth/MF2jG4JPscn8 è stata sostituita: non ripristinarla.
- Scope sigillum:originals:read, issuer e resource canonici sul dominio produzione.
- Connector e delegated audit attivati nel precedente rollout autorizzato; TLS mode RENDER_EDGE.
- Le verifiche live già eseguite mostravano health200/DBtrue, discovery200, MCP401 senza auth e Origin ostile403. Non sono state ripetute tutte durante questa lettura.

PRODUCTION_LIVE=false è un controllo commerciale/legale distinto dal deploy Render LIVE. render.production.yaml descrive default/prelaunch e non sostituisce i valori effettivi del servizio; non riapplicarlo ciecamente come configurazione attuale.

Nessun valore segreto è necessario per questa documentazione. La disponibilità del plugin privato nella UI dell'utente non prova che i suoi strumenti siano esposti in questa specifica chat.
