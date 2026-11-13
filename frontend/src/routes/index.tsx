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
      risposta: <>Solo sulla <strong>biglietteria esterna</strong> dell'evento: questa piattaforma non vende né emette biglietti.</>,
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
      <div className="home-hero">
        <p className="eyebrow">ARCADE MILANO &middot; {attiva?.anno ?? 2026}</p>
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
      </div>

      {errore && <p className="alert alert--error" role="alert">{errore}</p>}

      <section className="home-section">
        <p className="eyebrow">PERCH\u00c9 VISITARE</p>
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
          <div className="brief-item">
            <span>DOVE</span>
            <strong>{attiva?.sede ?? 'Sede in definizione'}</strong>
            <small>Milano</small>
          </div>
          <div className="brief-item">
            <span>QUANDO</span>
            <strong>{dateFiera ?? 'Date in definizione'}</strong>
            <small>{statoLabel ? `edizione ${attiva?.anno} \u00b7 ${statoLabel}` : 'edizione in definizione'}</small>
          </div>
          <div className="brief-item">
            <span>BIGLIETTI</span>
            <strong>Biglietteria esterna</strong>
            <small>la piattaforma non vende né emette biglietti</small>
          </div>
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
        <div className="panel">
          <div className="panel-heading">
            <div><p className="eyebrow">AVVISI PUBBLICI</p><h3>Comunicazioni per i visitatori</h3></div>
            <span className="count-pill">{avvisi.length}</span>
          </div>
          {avvisi.length === 0
            ? <p className="quiet-state">Nessun avviso pubblico al momento.</p>
            : avvisi.map((item) => (
              <article className="notice-card" key={item.id}>
                <div><strong>{item.titolo}</strong><small>{formatDate(item.pubblicatoIl)}</small></div>
                <p>{item.testo}</p>
              </article>
            ))}
        </div>
      </section>

      <p className="footnote">
        I biglietti si acquistano solo sulla biglietteria esterna: questa piattaforma non vende né emette biglietti.
      </p>
    </section>
  )
}
