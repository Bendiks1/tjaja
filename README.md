# Prisvakt

Scraper nettbutikker (Komplett, Power, Elkjøp, …), lagrer prishistorikk i SQLite og
gir **alarm** når en vare har falt ≥ 90 % i pris. Ingen eksterne avhengigheter (Python 3.10+).

## Bruk
```
cp config.example.json config.json   # legg til/fjern butikker, sett varsling
python -m prisvakt                    # én kjøring
python -m prisvakt --every 60         # sjekk hver time
python -m unittest discover -s tests  # tester
```

## Slik fungerer det
- Starter på `start_urls` (sitemap `.xml` eller kategorisider), følger lenker som matcher `link_pattern`
  (maks `max_pages`, `delay` sekunder mellom hver side).
- Leser varer fra schema.org JSON-LD på produktsider (fallback: Open Graph-meta).
- Alarm når pris er ≥ `threshold` (0.90) under **høyeste av**: tidligere observert pris og evt. «før-pris» siden oppgir.
  Hver (vare, pris) varsles bare én gang.
- Varsling: konsoll, pluss valgfritt push til mobil via [ntfy](https://ntfy.sh) (`ntfy_topic`) eller Discord/Slack-webhook.

## Testet mot ekte sider (7. okt. 2026)
| Butikk | Status |
|---|---|
| Power | ✅ Fungerer. Sitemap fra robots.txt, prisene stemmer med siden. |
| Elkjøp | ✅ Fungerer. Bedriftspris uten mva blir ignorert, bare vanlig pris brukes. |
| Komplett | ⚠️ Ikke verifisert. Svarte ikke fra skyserveren testen kjørte på (blokkerer trolig datasenter-IP-er). Prøv hjemmefra. |

## Hastighet
Alle butikker crawles parallelt. Per butikk styres farten av:
- `concurrency`: antall samtidige forespørsler
- `delay`: minste tid i sekunder mellom hver forespørsel (maks `1/delay` sider/s)

Hvis butikken svarer 429/503 («for mange forespørsler»), dobles pausen automatisk, og `Retry-After`
følges. Siden prøves på nytt, og farten går gradvis opp igjen. Etter 25 feil på rad (blokkert)
avbrytes den butikken for denne runden.

Målt 7. okt. 2026 med `concurrency: 8, delay: 0.1` (kort test, ingen 429 fra noen av butikkene):

| Butikk | Varer i sitemap | Fart | Full runde (`max_pages: 0`) |
|---|---|---|---|
| Power | ~36 600 | ~8,8 sider/s | ~1 time |
| Elkjøp | ~436 000 (~210 000 med utelatelsene i `config.example.json`) | ~4,7 sider/s (store sider, ~700 KB) | ~26 timer (~12,5 t med utelatelser) |

## Merk
- `max_pages` er antall sider per kjøring (sitemap-filer teller også). `0` = alle.
- `exclude_pattern`: regex for URL-er som hoppes over, f.eks. kategorier (se Elkjøp i `config.example.json`).
- Butikkene kan blokkere roboter eller bytte struktur. Sitemap-URL-er og `link_pattern` i
  `config.example.json` er utgangspunkt som må verifiseres mot hver butikk; sjekk også vilkårene deres.
- Sider som laster priser kun med JavaScript uten JSON-LD vil ikke gi treff.
- 90 % fall er sjeldent og kan være en prisfeil, noe som er poenget – men sjekk varen før du handler.
