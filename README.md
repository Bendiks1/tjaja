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

## Merk
- Butikkene kan blokkere roboter eller bytte struktur. Sitemap-URL-er og `link_pattern` i
  `config.example.json` er utgangspunkt som må verifiseres mot hver butikk; sjekk også vilkårene deres.
- Sider som laster priser kun med JavaScript uten JSON-LD vil ikke gi treff.
- 90 % fall er sjeldent og kan være en prisfeil, noe som er poenget – men sjekk varen før du handler.
