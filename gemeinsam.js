/* Gemeinsame Logik für Zentrale, Live-Seite und Abstimmseite. */
(function () {
  'use strict';
  const E = window.UMFRAGE_EINSTELLUNGEN || {};
  const URL_ = String(E.supabaseUrl || '').trim().replace(/\/+$/, '');
  const KEY = String(E.supabaseSchluessel || '').trim();

  /* ---------- kleine Helfer ---------- */
  const speicher = {
    lesen(k, standard) { try { const v = localStorage.getItem(k); return v === null ? standard : JSON.parse(v); } catch (_) { return standard; } },
    schreiben(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) {} }
  };
  function zufall(n) {
    const z = 'abcdefghijkmnpqrstuvwxyz23456789', a = new Uint8Array(n);
    crypto.getRandomValues(a);
    return Array.from(a, (b) => z[b % z.length]).join('');
  }
  let geraetFallback = null;
  function geraetId() {
    let g = speicher.lesen('umfrage_geraet', null);
    if (!g) { g = zufall(20); speicher.schreiben('umfrage_geraet', g); if (!speicher.lesen('umfrage_geraet', null)) g = geraetFallback = geraetFallback || g; }
    return g;
  }
  function modSchluessel() {
    let m = speicher.lesen('umfrage_mod', null);
    if (!m) { m = zufall(28); speicher.schreiben('umfrage_mod', m); }
    return m;
  }
  function setzeModSchluessel(m) { m = String(m || '').trim(); if (m.length >= 16) { speicher.schreiben('umfrage_mod', m); return true; } return false; }
  const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
  const param = (k) => new URLSearchParams(location.search).get(k);

  /* ---------- Schlüssel-Prüfung: niemals geheime Schlüssel im Browser ---------- */
  function schluesselFehler() {
    if (!URL_ && !KEY) return null;
    if (!URL_ || !KEY) return 'In einstellungen.js fehlt die Supabase-Adresse oder der Schlüssel.';
    if (!/^https:\/\//.test(URL_)) return 'Die Supabase-Adresse muss mit https:// beginnen.';
    if (/^sb_secret_/i.test(KEY)) return 'In einstellungen.js steht der GEHEIME Schlüssel. Bitte sofort durch den öffentlichen (Publishable) Schlüssel ersetzen.';
    if (/^eyJ/.test(KEY)) {
      try { const p = JSON.parse(atob(KEY.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))); if (p.role === 'service_role') return 'In einstellungen.js steht der GEHEIME service_role-Schlüssel. Bitte sofort durch den anon-Schlüssel ersetzen.'; } catch (_) {}
    }
    return null;
  }
  const fehlerText = schluesselFehler();
  const demo = !URL_ && !KEY;

  /* ---------- Backend 1: Supabase ---------- */
  async function rpcSupabase(fn, args) {
    if (fehlerText) throw new Error(fehlerText);
    const h = { 'Content-Type': 'application/json', apikey: KEY };
    if (/^eyJ/.test(KEY)) h.Authorization = 'Bearer ' + KEY;
    let r;
    try { r = await fetch(URL_ + '/rest/v1/rpc/' + fn, { method: 'POST', headers: h, body: JSON.stringify(args), cache: 'no-store' }); }
    catch (_) { throw new Error('Keine Verbindung. Internet prüfen oder Supabase-Projekt ist pausiert.'); }
    const t = await r.text(); let d = null; try { d = t ? JSON.parse(t) : null; } catch (_) {}
    if (!r.ok) throw new Error((d && (d.message || d.hint)) || ('Fehler ' + r.status));
    return d;
  }

  /* ---------- Backend 2: Demo-Modus im Browser (gleiche Regeln) ---------- */
  const DB = 'umfrage_demo_db';
  const ZEICHEN = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const SPERRE = ['arsch','fick','fotze','hure','nazi','neger','nigger','schlampe','wichser','hitler','fuck','shit','bitch','cunt','porn'];
  const hash = (s) => { let h = 2166136261; for (const c of String(s)) { h ^= c.codePointAt(0); h = Math.imul(h, 16777619); } return (h >>> 0).toString(16); };
  function fehler(m) { throw new Error(m); }
  const demoFn = {
    umfrage_anlegen({ p_frage, p_typ, p_optionen, p_mod }) {
      const db = speicher.lesen(DB, { u: {}, s: {} });
      const frage = String(p_frage || '').trim();
      if (frage.length < 1 || frage.length > 300) fehler('Die Frage muss 1 bis 300 Zeichen haben');
      if (!['einfach','mehrfach','skala','wolke'].includes(p_typ)) fehler('Unbekannter Fragetyp');
      let opt = Array.isArray(p_optionen) ? p_optionen : [];
      if ((p_typ === 'einfach' || p_typ === 'mehrfach') && (opt.length < 2 || opt.length > 12)) fehler('Bitte 2 bis 12 Antworten angeben');
      if (p_typ === 'skala' && opt.length !== 2) fehler('Die Skala braucht genau 2 Beschriftungen');
      if (p_typ === 'wolke') opt = [];
      if (opt.some((o) => typeof o !== 'string' || o.length > 80)) fehler('Jede Antwort darf höchstens 80 Zeichen haben');
      let code; do { code = Array.from({ length: 4 }, () => ZEICHEN[Math.floor(Math.random() * ZEICHEN.length)]).join(''); } while (db.u[code]);
      db.u[code] = { code, frage, typ: p_typ, optionen: opt, offen: true, runde: 1, ausgeblendet: [], mod_hash: hash(p_mod), erstellt: new Date().toISOString() };
      speicher.schreiben(DB, db); return { code };
    },
    umfrage_laden({ p_code }) {
      const u = speicher.lesen(DB, { u: {} }).u[String(p_code || '').trim().toUpperCase()];
      return u ? { code: u.code, frage: u.frage, typ: u.typ, optionen: u.optionen, offen: u.offen, runde: u.runde } : null;
    },
    stimme_abgeben({ p_code, p_geraet, p_antwort }) {
      const db = speicher.lesen(DB, { u: {}, s: {} }); const u = db.u[String(p_code || '').trim().toUpperCase()];
      if (!u) fehler('Umfrage nicht gefunden'); if (!u.offen) fehler('Die Umfrage ist geschlossen');
      if (!Array.isArray(p_antwort)) fehler('Ungültige Antwort');
      let a = [];
      if (u.typ === 'wolke') {
        for (const x of p_antwort) { if (typeof x !== 'string') fehler('Ungültige Antwort'); const w = x.trim().replace(/\s+/g, ' '); if (!w) continue; if (w.length > 30) fehler('Höchstens 30 Zeichen pro Begriff'); if (SPERRE.some((s) => w.toLowerCase().includes(s))) continue; if (!a.includes(w)) a.push(w); }
        if (a.length < 1) fehler('Bitte mindestens einen Begriff eingeben'); if (a.length > 3) fehler('Höchstens 3 Begriffe');
      } else {
        for (const x of p_antwort) { const k = Math.round(x); if (typeof x !== 'number') fehler('Ungültige Antwort'); if (u.typ === 'skala' ? (k < 1 || k > 10) : (k < 0 || k >= u.optionen.length)) fehler('Ungültige Antwort'); if (!a.includes(k)) a.push(k); }
        if (a.length < 1) fehler('Bitte eine Antwort wählen'); if (u.typ !== 'mehrfach' && a.length > 1) fehler('Nur eine Antwort erlaubt');
      }
      db.s[u.code + '|' + u.runde + '|' + p_geraet] = a; speicher.schreiben(DB, db); return { ok: true, runde: u.runde };
    },
    umfrage_ergebnis({ p_code }) {
      const db = speicher.lesen(DB, { u: {}, s: {} }); const u = db.u[String(p_code || '').trim().toUpperCase()];
      if (!u) fehler('Umfrage nicht gefunden');
      const pre = u.code + '|' + u.runde + '|'; const st = Object.keys(db.s).filter((k) => k.startsWith(pre)).map((k) => db.s[k]);
      let werte;
      if (u.typ === 'wolke') {
        const m = new Map(); st.flat().forEach((w) => { const k = w.toLowerCase(); if (u.ausgeblendet.includes(k)) return; const o = m.get(k) || { wort: w, anzahl: 0 }; o.anzahl++; if (w < o.wort) o.wort = w; m.set(k, o); });
        werte = [...m.values()].sort((a, b) => b.anzahl - a.anzahl || a.wort.localeCompare(b.wort)).slice(0, 60);
      } else { werte = {}; st.flat().forEach((k) => { werte[k] = (werte[k] || 0) + 1; }); }
      return { code: u.code, frage: u.frage, typ: u.typ, optionen: u.optionen, offen: u.offen, runde: u.runde, anzahl: st.length, werte };
    },
    umfrage_steuern({ p_code, p_mod, p_aktion, p_wert }) {
      const db = speicher.lesen(DB, { u: {}, s: {} }); const u = db.u[String(p_code || '').trim().toUpperCase()];
      if (!u) fehler('Umfrage nicht gefunden'); if (u.mod_hash !== hash(p_mod)) fehler('Kein Zugriff: falscher Moderations-Schlüssel');
      if (p_aktion === 'oeffnen') u.offen = true;
      else if (p_aktion === 'schliessen') u.offen = false;
      else if (p_aktion === 'neue_runde') { Object.keys(db.s).forEach((k) => { if (k.startsWith(u.code + '|')) delete db.s[k]; }); u.runde++; u.offen = true; u.ausgeblendet = []; }
      else if (p_aktion === 'ausblenden') { const w = String(p_wert || '').trim().toLowerCase(); if (!u.ausgeblendet.includes(w)) u.ausgeblendet.push(w); }
      else if (p_aktion === 'einblenden') u.ausgeblendet = [];
      else if (p_aktion === 'loeschen') { delete db.u[u.code]; Object.keys(db.s).forEach((k) => { if (k.startsWith(u.code + '|')) delete db.s[k]; }); speicher.schreiben(DB, db); return { ok: true, geloescht: true }; }
      else fehler('Unbekannte Aktion');
      speicher.schreiben(DB, db); return { ok: true };
    },
    meine_umfragen({ p_mod }) {
      const db = speicher.lesen(DB, { u: {}, s: {} }); const h = hash(p_mod);
      return Object.values(db.u).filter((u) => u.mod_hash === h).sort((a, b) => b.erstellt.localeCompare(a.erstellt)).map((u) => {
        const pre = u.code + '|' + u.runde + '|';
        return { code: u.code, frage: u.frage, typ: u.typ, optionen: u.optionen, offen: u.offen, runde: u.runde, erstellt: u.erstellt, anzahl: Object.keys(db.s).filter((k) => k.startsWith(pre)).length };
      });
    }
  };
  async function rpc(fn, args) {
    if (demo) { await new Promise((r) => setTimeout(r, 120)); return demoFn[fn](args); }
    return rpcSupabase(fn, args);
  }

  /* ---------- API ---------- */
  const api = {
    anlegen: (frage, typ, optionen) => rpc('umfrage_anlegen', { p_frage: frage, p_typ: typ, p_optionen: optionen, p_mod: modSchluessel() }),
    laden: (code) => rpc('umfrage_laden', { p_code: code }),
    abstimmen: (code, antwort) => rpc('stimme_abgeben', { p_code: code, p_geraet: geraetId(), p_antwort: antwort }),
    ergebnis: (code) => rpc('umfrage_ergebnis', { p_code: code }),
    steuern: (code, aktion, wert) => rpc('umfrage_steuern', { p_code: code, p_mod: modSchluessel(), p_aktion: aktion, p_wert: wert === undefined ? null : wert }),
    meine: () => rpc('meine_umfragen', { p_mod: modSchluessel() })
  };

  /* ---------- Adressen und QR-Code ---------- */
  const basisUrl = () => new URL('./', location.href).href;
  const abstimmUrl = (code) => new URL('./?c=' + encodeURIComponent(code), location.href).href;
  const liveUrl = (code, extra) => new URL('live.html?c=' + encodeURIComponent(code) + (extra || ''), location.href).href;
  const kurzAdresse = () => basisUrl().replace(/^https?:\/\//, '').replace(/\/$/, '');
  function qrSvg(text) {
    const q = qrcode(0, 'M'); q.addData(text, 'Byte'); q.make();
    const n = q.getModuleCount(), m = 2; let d = '';
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) if (q.isDark(y, x)) d += 'M' + (x + m) + ' ' + (y + m) + 'h1v1h-1z';
    const s = n + 2 * m;
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + s + ' ' + s + '" shape-rendering="crispEdges" role="img" aria-label="QR-Code zur Abstimmung"><rect width="' + s + '" height="' + s + '" fill="#fff"/><path d="' + d + '" fill="#050D1C"/></svg>';
  }

  const TYPEN = { einfach: 'Einfachauswahl', mehrfach: 'Mehrfachauswahl', skala: 'Skala 1-10', wolke: 'Wortwolke' };

  window.Umfrage = { api, demo, fehlerText, el, param, speicher, geraetId, modSchluessel, setzeModSchluessel, abstimmUrl, liveUrl, basisUrl, kurzAdresse, qrSvg, TYPEN };
})();
