# Video Downloader

Lokalna Windows aplikacija za preuzimanje javno dostupnih videa sa YouTube-a,
X/Twittera, Instagrama i drugih sajtova koje podržava `yt-dlp`.

GitHub projekat: https://github.com/montazainformer-coder/informer-video-downloader

Interfejs uključuje lokalni portret-panel **Naša Šefica** iz `assets` foldera.

## Pokretanje

1. Raspakuj ceo folder na željeno mesto.
2. Dvoklikni `INSTALL.bat` da napraviš Desktop prečicu.
3. Pokreni **Video Downloader** sa Desktopa.
4. Nalepi link i klikni **Proveri link**.
5. Izaberi folder i klikni **Preuzmi 1080p**.

Možeš ga pokrenuti i direktno preko `Start-Downloader.bat`, bez instalacije
prečice. Desktop prečica koristi `Launch-Downloader.ps1`, bez Windows Script
Host zavisnosti.

Pri prvom preuzimanju aplikacija automatski dodaje zvanični `yt-dlp` i FFmpeg u
lokalni `tools` folder. Potreban je internet i prvi start može trajati malo duže.

Aplikacija ostaje otvorena posle završenog preuzimanja. Ako se veza prekine,
`.part` fajl se čuva i ponavljanje istog linka nastavlja od prethodnog mesta.
Neočekivane greške se zapisuju u `downloader-crash.log`.

## Ažuriranje

Aplikacija automatski proverava najnoviji GitHub Release pri pokretanju. Proveru
možeš pokrenuti i ručno dugmetom **Proveri ažuriranje**. Update paket se proverava
SHA-256 hashom pre instalacije, a postojeći `tools` folder i preuzeti video fajlovi
ostaju netaknuti.

Za novu verziju promeni kod, pa na razvojnom računaru pokreni
`PUBLISH-UPDATE.bat`. Unesi verziju kao `1.1.0` i kratak opis. Skripta će sama
napraviti commit i Git tag, a GitHub Actions će automatski napraviti Release i
update ZIP.

## Izvor videa

Za svaki video se pravi i `video.ext.source.txt` sa originalnim URL-om.

Kada je opcija za izvor uključena, URL stranice se upisuje u metadata komentar,
a pored videa se čuvaju `.info.json` i `.description` fajlovi. Oni sadrže originalni
URL, autora/uploadera i ostale javno dostupne podatke.

## Izlazni format

- **MP4** koristi H.264 video i AAC-LC 48 kHz stereo audio. Namenjen je
  svakodnevnoj upotrebi, deljenju i direktnom uvozu u Premiere.
- **MXF** prvo preuzima MP4, zatim ga pretvara u DNxHR HQ 4:2:2 video i PCM
  24-bit/48 kHz audio. Namenjen je montaži i može biti 20–50 puta veći od MP4-a.

## Napomene

- Kvalitet je najbolji dostupan do 1080p; neki sajtovi nude samo nižu rezoluciju.
- Završni MP4 preferira H.264 video i koristi AAC-LC 48 kHz stereo audio radi
  kompatibilnosti sa Adobe Premiere Pro.
- MXF konverzija čuva privremeni MP4 ako konverzija ne uspe.
- Privatni sadržaj, DRM i zaštite pristupa se ne zaobilaze.
- Preuzimaj samo sadržaj za koji imaš dozvolu i poštuj uslove korišćenja sajta.
- Sajtovi povremeno menjaju način rada; osvežavanje `tools\yt-dlp.exe` na noviju
  verziju obično rešava problem.
