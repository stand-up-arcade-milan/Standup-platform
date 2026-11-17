import { createFileRoute, Link } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { api, formatDate } from '../services/api'

export const Route = createFileRoute('/')({ component: HomePage })

type Edizione = {
  anno: number
  sede?: string | null
  stato?: 'PIANIFICATA' | 'ATTIVA' | 'CONCLUSA'
  inizioFiera?: string | null
  fineFiera?: string | null
}

type Avviso = { id: string; titolo: string; testo: string; pubblicatoIl: string; attivo: boolean }

const PERCHE: { titolo: string; testo: ReactNode }[] = [
  {
    titolo: 'Un festival, un solo portale',
    testo: <>ARCADE riunisce gaming e cultura pop a Milano. Questo portale è il punto d'ingresso unico: <em>visitatori, espositori e staff</em> accedono tutti con email e password e vedono solo la propria area.</>,
  },
  {
    titolo: 'Informazioni ufficiali',
    testo: <>Date, sede e <em>avvisi pubblici</em> dell'organizzazione arrivano direttamente da qui: niente canali paralleli, le comunicazioni per i visitatori sono pubblicate in questa pagina.</>,
  },
  {
    titolo: 'Un evento che si misura',
    testo: <>Dietro le quinte, varchi, affluenza e turni del personale sono monitorati in tempo reale dall'organizzazione: <em>un evento più sicuro e più fluido</em> per chi visita.</>,
  },
]

function HomePage() {
  const [edizioni, setEdizioni] = useState<Edizione[]>([])
  const [avvisi, setAvvisi] = useState<Avviso[]>([])
  const [errore, setErrore] = useState<string | null>(null)

  useEffect(() => {
    api<{ items: Edizione[] }>('/edizioni')
      .then((data) => setEdizioni((data.items ?? []).sort((a, b) => b.anno - a.anno)))
      .catch(() => setErrore('Edizioni non disponibili: controlla che i servizi siano avviati.'))
    api<{ items: Avviso[] }>('/avvisi?pubblico=VISITATORI')
      .then((data) => setAvvisi((data.items ?? []).filter((item) => item.attivo)))
      .catch(() => setAvvisi([]))
  }, [])

  const attiva = edizioni.find((item) => item.stato === 'ATTIVA') ?? edizioni[0] ?? null
  const dateFiera = attiva?.inizioFiera
    ? `${formatDate(attiva.inizioFiera)}${attiva.fineFiera ? ` – ${formatDate(attiva.fineFiera)}` : ''}`
    : null
  const statoLabel = attiva?.stato === 'ATTIVA' ? 'in corso' : attiva?.stato === 'CONCLUSA' ? 'conclusa' : attiva ? 'in preparazione' : null

  const faq: { domanda: string; risposta: ReactNode }[] = [
    {
      domanda: 'Come accedo al portale?',
      risposta: <>Con <strong>email e password</strong> dalla <Link to="/accesso">schermata di accesso</Link>: ogni ruolo — direzione, espositore, staff, commerciale, amministrazione — passa dallo stesso accesso e vede solo la propria area.</>,
    },
    {
      domanda: 'Dove acquisto i biglietti?',
      risposta: <>Dalla pagina <Link to="/biglietteria">biglietteria</Link> del portale, in arrivo a breve.</>,
    },
    {
      domanda: 'Come mi registro come visitatore?',
      risposta: <>La registrazione dei visitatori è <strong>in arrivo</strong>: per ora il portale pubblico mostra edizione, sede, date e avvisi ufficiali.</>,
    },
    {
      domanda: 'Come richiedo uno stand?',
      risposta: <>Il modulo di richiesta stand è <strong>in arrivo</strong>: chi ha già un account espositore trova contratti, documenti e stato della richiesta nella propria area.</>,
    },
    {
      domanda: 'Quanti visitatori ha fatto l\u2019ultima edizione?',
      risposta: <>I contatori delle edizioni precedenti <strong>non sono ancora pubblici</strong>: i dati di affluenza e ricavi sono riservati all'organizzazione.</>,
    },
  ]

  return (
    <section className="home-page">
      <TitoloStrati testo="ARCADE Milano" />

      <div className="home-hero">
        <div className="home-hero__testo">
          <p className="home-hero__pill">Festival &middot; 3 giorni &middot; {attiva?.anno ?? 2026}</p>
          <h2>Benvenuto al festival del gaming e della cultura pop</h2>
          <p className="home-hero__where">
            Milano{dateFiera ? `, ${dateFiera}` : ' \u00b7 date in definizione'}
          </p>
          <p className="home-hero__lead">
            Tre giorni di fiera, community e gioco: un unico portale per visitatori, espositori e staff,
            con le informazioni ufficiali dell'organizzazione sempre aggiornate.
          </p>
          <div className="cta-row">
            <Link className="button button--lime" to="/accesso">Accedi al portale</Link>
            <button type="button" className="button button--dark" disabled title="Registrazione visitatori in arrivo">
              Registrati come visitatore
            </button>
            <button type="button" className="button button--dark" disabled title="Richiesta stand in arrivo">
              Richiedi uno stand
            </button>
          </div>
          <p className="home-hero__nota">I biglietti si acquistano dalla <Link to="/biglietteria">pagina biglietteria</Link>.</p>
        </div>
      </div>

      {errore && <p className="alert alert--error" role="alert">{errore}</p>}

      <section className="home-section">
        <p className="eyebrow">PERCHÉ VISITARE</p>
        <h3>Perché venire ad ARCADE</h3>
        <div className="why-grid">
          {PERCHE.map((item) => (
            <article className="why-card" key={item.titolo}>
              <strong>{item.titolo}</strong>
              <p>{item.testo}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="home-section">
        <p className="eyebrow">IN BREVE</p>
        <h3>ARCADE in breve</h3>
        <div className="home-brief">
          <Link to="/sede" className="brief-item brief-item--link brief-item--sede">
            <IconaSede />
            <span>DOVE</span>
            <strong>{attiva?.sede ?? 'Sede in definizione'}</strong>
            <small>Milano &middot; vai alla mappa &rarr;</small>
          </Link>
          <Link to="/calendario" className="brief-item brief-item--link brief-item--calendario">
            <IconaCalendario />
            <span>QUANDO</span>
            <strong>{dateFiera ?? 'Date in definizione'}</strong>
            <small>{statoLabel ? `edizione ${attiva?.anno} \u00b7 ${statoLabel}` : 'edizione in definizione'} &middot; masterclass &rarr;</small>
          </Link>
          <Link to="/biglietteria" className="brief-item brief-item--link brief-item--biglietti">
            <IconaBiglietto />
            <span>BIGLIETTI</span>
            <strong>In arrivo</strong>
            <small>Vai alla pagina biglietteria &rarr;</small>
          </Link>
        </div>
      </section>

      <section className="home-section">
        <p className="eyebrow">FAQ</p>
        <h3>Domande frequenti</h3>
        <div className="faq-list">
          {faq.map((item) => (
            <details key={item.domanda}>
              <summary>{item.domanda}</summary>
              <p>{item.risposta}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="home-section">
        <p className="eyebrow">AVVISI PUBBLICI</p>
        <h3>Comunicazioni per i visitatori <span className="count-pill">{avvisi.length}</span></h3>
        {avvisi.length === 0
          ? <p className="quiet-state">Nessun avviso pubblico al momento.</p>
          : (
            <div className="news-grid">
              {avvisi.map((item) => (
                <article className="news-card" key={item.id}>
                  <small>{formatDate(item.pubblicatoIl)}</small>
                  <strong>{item.titolo}</strong>
                  <p>{item.testo}</p>
                </article>
              ))}
            </div>
          )}
      </section>

      <p className="footnote">
        I biglietti si acquistano dalla <Link to="/biglietteria">pagina biglietteria</Link> del portale, in arrivo a breve.
      </p>
    </section>
  )
}

const STRATI = 26
const PASSO = 7
const BASE = 330
// larghezza fissa: il titolo occupa la stessa riga con qualunque font disponibile sul dispositivo
const LARGHEZZA = 1255

/**
 * Titolo a contorno con gli strati che salgono dietro, come nella bozza delle schermate.
 * In SVG: la sfumatura della palette colora solo i contorni e la scritta si adatta alla larghezza.
 */
function IconaSede() {
  return (
    <svg className="brief-item__icona" viewBox="0 0 48 48" fill="none" aria-hidden="true">
      <path d="M24 44s14-12.2 14-22a14 14 0 0 0-28 0c0 9.8 14 22 14 22Z" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round" />
      <circle cx="24" cy="22" r="5.5" stroke="currentColor" strokeWidth="2.4" />
    </svg>
  )
}

function IconaCalendario() {
  return (
    <svg className="brief-item__icona" viewBox="0 0 48 48" fill="none" aria-hidden="true">
      <rect x="6" y="10" width="36" height="32" rx="4" stroke="currentColor" strokeWidth="2.4" />
      <path d="M6 19h36M15 5v9M33 5v9" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
      <path d="M15 27h4M23 27h4M31 27h4M15 34h4M23 34h4" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  )
}

function IconaBiglietto() {
  return (
    <svg className="brief-item__icona brief-item__icona--biglietto" viewBox="0 0 48 32" fill="none" aria-hidden="true">
      <path
        d="M4 10a3 3 0 0 0 0 6v6a2 2 0 0 0 2 2h36a2 2 0 0 0 2-2v-6a3 3 0 0 1 0-6V4a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v6Z"
        stroke="currentColor" strokeWidth="2.2" strokeLinejoin="round"
      />
      <path d="M30 2v28" stroke="currentColor" strokeWidth="2.2" strokeDasharray="2.6 2.6" strokeLinecap="round" />
    </svg>
  )
}

function TitoloStrati({ testo }: { testo: string }) {
  const livelli = Array.from({ length: STRATI }, (_, i) => STRATI - i)
  return (
    <svg className="titolo-strati" viewBox="0 0 1270 340" preserveAspectRatio="xMinYMax meet" role="img" aria-label={testo}>
      <defs>
        <linearGradient id="strati-tinta" x1="0" x2="1270" y1="0" y2="0" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#cbff8c" />
          <stop offset=".5" stopColor="#3f826d" />
          <stop offset="1" stopColor="#c03221" />
        </linearGradient>
        <linearGradient id="strati-sfuma" x1="0" x2="0" y1="0" y2="340" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#fff" />
          <stop offset=".45" stopColor="#fff" />
          <stop offset=".9" stopColor="#fff" stopOpacity=".15" />
        </linearGradient>
        <mask id="strati-maschera" maskUnits="userSpaceOnUse" x="0" y="0" width="1270" height="340">
          <rect width="1270" height="340" fill="url(#strati-sfuma)" />
        </mask>
      </defs>
      <g mask="url(#strati-maschera)" aria-hidden="true">
        {livelli.map((livello) => (
          <text key={livello} x="0" y={BASE - livello * PASSO} className="titolo-strati__eco" textLength={LARGHEZZA} lengthAdjust="spacingAndGlyphs">{testo}</text>
        ))}
      </g>
      <text x="0" y={BASE} className="titolo-strati__fronte" textLength={LARGHEZZA} lengthAdjust="spacingAndGlyphs" aria-hidden="true">{testo}</text>
    </svg>
  )
}
