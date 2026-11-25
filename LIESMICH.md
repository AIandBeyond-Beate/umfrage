# Live-Umfrage-Tool

Umfragen per QR-Code in Online-Meetings. Teilnehmende scannen mit dem Handy, stimmen ab, das Ergebnis erscheint live auf deiner Folie. Im AI-&-Beyond-Konferenzdesign.

## Was drin ist

- 👉 `zentrale.html`: deine Zentrale. Umfragen anlegen, Live-Ansicht öffnen, Einbett-Code holen, schließen, zurücksetzen, löschen.
- 👉 `live.html`: die Präsentationsansicht mit Frage, QR-Code, Code zum Abtippen und Live-Ergebnis.
- 👉 `index.html`: die Handy-Seite für Teilnehmende. Wer die Adresse ohne Code öffnet, kann den Code eintippen.
- 👉 `einstellungen.js`: deine 2 Supabase-Werte. Die einzige Datei, die du anpasst.
- 👉 `supabase-einrichten.sql`: einmal in Supabase ausführen.
- 👉 `lib/`: Schrift Raleway, QR-Code-Generator, Logo. Alles lokal, keine Google-Server.

Fragetypen:

- ✅ Einfachauswahl (2 bis 12 Antworten)
- ✅ Mehrfachauswahl (2 bis 12 Antworten)
- ✅ Skala 1-10 mit Durchschnitt und Verteilung
- ✅ Wortwolke (bis 3 Begriffe pro Person, je 30 Zeichen)

---

## Sofort ausprobieren: Demo-Modus

Solange `einstellungen.js` leer ist, läuft alles nur in deinem Browser.

1. `Umfrage_starten.bat` doppelklicken. Der Browser öffnet die Zentrale.
2. Umfrage anlegen, „Live zeigen“ klicken.
3. In einem zweiten Tab „Abstimmseite“ öffnen und abstimmen. Die Live-Ansicht zählt mit.

Handys funktionieren im Demo-Modus nicht. Dafür brauchst du Schritt 1 bis 3.

---

## Schritt 1: Supabase einrichten (ca. 10 Minuten, einmalig)

1. Auf supabase.com ein kostenloses Konto anlegen.
2. „New project“ klicken.
   - Name: zum Beispiel `umfrage`
   - Database Password: sicheres Passwort, im Passwort-Manager ablegen. Brauchst du für dieses Tool nicht wieder.
   - Region: **Central EU (Frankfurt)**
3. Warten, bis das Projekt fertig ist (1-2 Minuten).
4. Links „SQL Editor“ öffnen, „New query“ klicken.
5. Den kompletten Inhalt von `supabase-einrichten.sql` einfügen, „Run“ klicken. Ergebnis: „Success. No rows returned“.

Hinweis: Die Menünamen bei Supabase ändern sich ab und zu. Stand November 2026.

## Schritt 2: Die 2 Werte eintragen

In Supabase:

- 👉 **Projekt-Adresse**: oben auf „Connect“ klicken oder unter Project Settings → Data API. Sieht so aus: `https://abcdefghijklmnop.supabase.co`
- 👉 **Öffentlicher Schlüssel**: Project Settings → API Keys. Nimm den **Publishable key** (beginnt mit `sb_publishable_`) oder, falls nur der angezeigt wird, den **anon public** Key (beginnt mit `eyJ`).

⚠️ Niemals den **Secret key** oder **service_role** Key eintragen. Das Tool erkennt das und blockiert.

Beide Werte in `einstellungen.js` zwischen die Anführungszeichen kopieren und speichern.

Der öffentliche Schlüssel darf öffentlich sein. Er erlaubt nur das, was die 6 Funktionen aus Schritt 1 zulassen: anlegen, abstimmen, Ergebnis lesen. Schließen, Zurücksetzen und Löschen gehen nur mit deinem Moderations-Schlüssel.

## Schritt 3: Online stellen mit GitHub Pages

Die Handys deiner Teilnehmenden brauchen eine Adresse im Internet.

1. Auf github.com ein neues Repository anlegen, **Public**, Name zum Beispiel `umfrage`.
2. „Add file“ → „Upload files“: den **Inhalt** des Ordners `umfrage-tool` hineinziehen, inklusive Ordner `lib`. „Commit changes“.
3. Settings → Pages → Source: „Deploy from a branch“, Branch `main`, Ordner `/ (root)`, Save.
4. Nach 1-2 Minuten läuft alles unter:
   - Zentrale: `https://DEIN-NAME.github.io/umfrage/zentrale.html`
   - Handy-Seite: `https://DEIN-NAME.github.io/umfrage/`

Alles in diesem Ordner darf öffentlich sein. Die lizenzpflichtige Arkhip-Schrift ist nicht dabei, Raleway steht unter freier Lizenz (OFL).

Tipp: Die Zentrale als Lesezeichen speichern.

---

## Im Meeting

1. Zentrale öffnen, Umfrage anlegen (geht auch Tage vorher).
2. „Live zeigen“ klicken, Fenster im Meeting teilen.
3. Teilnehmende scannen den QR-Code oder tippen Adresse + Code ein.

Tasten auf der Live-Seite:

- `Leertaste` oder `E`: Ergebnis zeigen / verbergen (erst abstimmen lassen, dann auflösen)
- `S`: Abstimmung schließen / wieder öffnen. Beim Schließen hebt sich der Gewinner hervor.
- `R`: Neue Runde, alle Antworten auf 0
- `Q`: QR-Code groß / klein
- `F`: Vollbild

Wenn du die Maus bewegst, erscheinen dieselben Funktionen als Knöpfe unten rechts.

Bei Wortwolken: Begriff anklicken → ausblenden. Grobe Schimpfwörter filtert das Tool automatisch.

Nützliche Zusätze für die Adresse der Live-Seite:

- `&verdeckt=1`: Ergebnis startet verborgen
- `&start=qr`: Seite startet mit großem QR-Code
- `&qr=0`: ohne QR-Spalte, Ergebnis über volle Breite

## In deine HTML-Folie einbetten

1. In der Zentrale bei der Umfrage „Einbett-Code“ klicken.
2. Variante wählen: mit QR-Code oder nur Ergebnis.
3. „Code kopieren“ und in die Folie einfügen, in den `<section>`-Block der Folie.

Die Umfrage füllt die ganze Folie (1920 × 1080). Der Hintergrund bleibt durchsichtig, dein Folien-Design scheint durch. Die zweite Zeile des Codes sorgt dafür, dass Pfeiltasten und Leertaste weiter deine Folien umblättern, auch wenn du vorher in die Umfrage geklickt hast. Steuern mit `E`, `S`, `R`, `Q` geht trotzdem.

Wichtig: Die Folie muss online sein oder über den lokalen Server laufen (wie bei `Deck_starten.bat`). Und das Steuern (Schließen, Neue Runde) klappt nur in dem Browser, in dem du die Umfrage angelegt hast. Sonst: Moderations-Schlüssel übertragen (siehe unten).

## Zweites Gerät: Moderations-Schlüssel

Der Schlüssel wird beim ersten Öffnen der Zentrale erzeugt und liegt in diesem Browser.

1. Zentrale → „Moderations-Schlüssel“ aufklappen → „Kopieren“.
2. Auf dem anderen Gerät Zentrale öffnen → Schlüssel einfügen → „Übernehmen“.

Behandle ihn wie ein Passwort. Wer ihn hat, kann deine Umfragen schließen und löschen.

---

## Checkliste vor jedem Meeting

- ✅ Supabase-Dashboard öffnen. Gratis-Projekte pausieren nach 7 Tagen ohne Nutzung. Steht dort „Paused“: „Restore project“ klicken, 1-2 Minuten warten.
- ✅ Live-Seite öffnen, mit dem eigenen Handy QR-Code scannen, Test-Stimme abgeben.
- ✅ Zähler springt auf 1? Dann `R` drücken (Neue Runde), fertig.
- ✅ Im Meeting-Tool Bildschirm teilen und prüfen, ob der QR-Code groß genug ist. Sonst `Q`.

## Datenschutz

- ✅ Gespeichert wird nur: Umfrage-Code, gewählte Antwort, eine zufällige Geräte-Nummer gegen Doppelabstimmung. Kein Name, keine E-Mail.
- ✅ Die Datenbank speichert keine IP-Adressen. Supabase selbst führt technische Server-Protokolle (Hinweis gehört in deine Datenschutzerklärung).
- ✅ Server in Frankfurt (EU). Den Auftragsverarbeitungsvertrag (DPA) von Supabase findest du im Dashboard bei den rechtlichen Dokumenten deiner Organisation. Abschließen, bevor du das Tool mit Kunden nutzt.
- ✅ Keine Google Fonts, keine externen Skripte. Alles liegt im Ordner `lib`.
- ✅ Teilnehmende sehen auf der Handy-Seite: „Anonym. Es werden keine persönlichen Daten gespeichert, nur deine Antwort.“
- ✅ Bei „Neue Runde“ und „Löschen“ werden die Antworten endgültig gelöscht.

## Grenzen

- 👉 Kostenloser Supabase-Plan: 500 MB Datenbank, reicht für Zehntausende Antworten.
- 👉 Live-Ansicht aktualisiert alle 2 Sekunden.
- 👉 „Eine Stimme pro Gerät“ hängt am Browser. Wer den Browser-Speicher löscht oder ein privates Fenster nutzt, kann nochmal abstimmen. Für Meetings reicht das, für Wahlen nicht.
