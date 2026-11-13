import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { api, formatDate } from '../services/api'
import { useAuth } from '../components/AuthProvider'
import { homeFor } from '../services/auth'

export const Route = createFileRoute('/')({ component: HomePage })

type Edizione = {
  anno: number
  sede?: string | null
  stato?: 'PIANIFICATA' | 'ATTIVA' | 'CONCLUSA'
  inizioFiera?: string | null
  fineFiera?: string | null
}

type Avviso = { id: string; titolo: string; testo: string; pubblicatoIl: string; attivo: boolean }

function IconaBiglietto() {
  return (
    <svg className="strip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
      <path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z" />
      <path d="M13 5v2" /><path d="M13 11v2" /><path d="M13 17v2" />
    </svg>
  )
}

function IconaMappa() {
  return (
    <svg className="strip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
      <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21" />
      <line x1="9" y1="3" x2="9" y2="18" /><line x1="15" y1="6" x2="15" y2="21" />
    </svg>
  )
}

function IconaRegistrazione() {
  return (
    <svg className="strip-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z" />
      <polyline points="14 2 14 8 20 8" /><line x1="16" y1="13" x2="8" y2="13" /><line x1="16" y1="17" x2="8" y2="17" />
    </svg>
  )
}

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
  const { session } = useAuth()
  const navigate = useNavigate()
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

  const scorriA = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })

  return (
    <section className="home-page">
      <div className="home-hero">
        <div className="home-hero__content">
          <p className="eyebrow">STAND UP PRESENTA</p>
          <h2>ARCADE Milano {attiva?.anno ?? 2026}</h2>
          <p className="home-hero__where">
            Gaming e cultura pop, tutto in un posto
            {dateFiera ? ` \u00b7 ${dateFiera}` : ''}
            {attiva?.sede ? ` \u00b7 ${attiva.sede}` : ''}
          </p>
          <p className="home-hero__lead">
            Tre giorni aperti al pubblico: tornei, anteprime, cosplay e creator. Le informazioni
            ufficiali dell'organizzazione arrivano da questo portale.
          </p>
          <div className="home-hero__ctas">
            <button type="button" className="button button--lime home-cta-xl" onClick={() => scorriA('informazioni')}>
              VISITA
            </button>
            <button type="button" className="button button--outline home-cta-xl" onClick={() => scorriA('faq')}>
              ESPONI
            </button>
            {session ? (
              <button type="button" className="button button--dark" onClick={() => void navigate({ to: homeFor(session.role) })}>
                Vai alla tua area
              </button>
            ) : (
              <Link className="button button--dark" to="/accesso">Accedi al portale</Link>
            )}
          </div>
        </div>
      </div>

      {errore && <p className="alert alert--error" role="alert">{errore}</p>}

      <div className="home-strip">
        <article className="strip-card">
          <IconaBiglietto />
          <strong>Biglietteria aperta</strong>
          <p>I biglietti si acquistano solo sulla biglietteria ufficiale esterna dell'evento.</p>
          <button type="button" className="text-button" onClick={() => scorriA('faq')}>DI PIÙ</button>
        </article>
        <article className="strip-card">
          <IconaMappa />
          <strong>Catalogo e mappa stand</strong>
          <p>L'elenco degli espositori e la mappa degli stand arrivano con le schermate dedicate.</p>
          <button type="button" className="text-button" onClick={() => scorriA('faq')}>DI PIÙ</button>
        </article>
        <article className="strip-card">
          <IconaRegistrazione />
          <strong>Registrazione</strong>
          <p>Registrazione visitatori e richiesta stand: in arrivo su questo portale.</p>
          <button type="button" className="text-button" onClick={() => scorriA('faq')}>DI PIÙ</button>
        </article>
      </div>

      <section className="home-section" id="informazioni">
        <p className="eyebrow">INFO UTILI</p>
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
        <div className="panel-heading">
          <div><p className="eyebrow">NOVITÀ E AVVISI</p><h3>Comunicazioni per i visitatori</h3></div>
          <span className="count-pill">{avvisi.length}</span>
        </div>
        {avvisi.length === 0
          ? <p className="quiet-state">Nessun avviso pubblico al momento.</p>
          : <div className="news-grid">
              {avvisi.map((item) => (
                <article className="news-card" key={item.id}>
                  <div><strong>{item.titolo}</strong><small>{formatDate(item.pubblicatoIl)}</small></div>
                  <p>{item.testo}</p>
                </article>
              ))}
            </div>}
      </section>

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

      <section className="home-section" id="faq">
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

      <p className="footnote">
        I biglietti si acquistano solo sulla biglietteria esterna: questa piattaforma non vende né emette biglietti.
      </p>
    </section>
  )
}
