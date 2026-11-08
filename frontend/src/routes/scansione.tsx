import { createFileRoute } from '@tanstack/react-router'
import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { api, ApiError, readToken, saveToken } from '../services/api'

export const Route = createFileRoute('/scansione')({ component: ScanPage })

type ScanResult = { eventId: string; accettata: boolean; duplicata: boolean; conteggioStand: number; messaggio?: string }
type LeadMagnet = { id: number; titolo: string; tipo: string }
type Barcode = { rawValue: string }
type Detector = { detect: (source: HTMLVideoElement) => Promise<Barcode[]> }
type DetectorWindow = Window & { BarcodeDetector?: new (options?: { formats?: string[] }) => Detector }

function ScanPage() {
  const [edition, setEdition] = useState('2026')
  const [stand, setStand] = useState('')
  const [operator, setOperator] = useState('')
  const [tokenInput, setTokenInput] = useState(readToken('internal') ?? '')
  const [ticketRef, setTicketRef] = useState('')
  const [email, setEmail] = useState('')
  const [shareContact, setShareContact] = useState(false)
  const [consentExhibitors, setConsentExhibitors] = useState(false)
  const [leadMagnets, setLeadMagnets] = useState<LeadMagnet[]>([])
  const [leadMagnetId, setLeadMagnetId] = useState('')
  const [cameraMessage, setCameraMessage] = useState('')
  const [cameraOn, setCameraOn] = useState(false)
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState<ScanResult | null>(null)
  const [error, setError] = useState('')
  const video = useRef<HTMLVideoElement>(null)
  const stream = useRef<MediaStream | null>(null)
  const frame = useRef<number | null>(null)

  useEffect(() => () => {
    if (frame.current != null) cancelAnimationFrame(frame.current)
    stream.current?.getTracks().forEach((track) => track.stop())
    stream.current = null
  }, [])
  useEffect(() => {
    api<{ items: LeadMagnet[] }>(`/lead-magnet?edizione=${encodeURIComponent(edition)}`)
      .then((response) => setLeadMagnets(response.items ?? []))
      .catch(() => setLeadMagnets([]))
  }, [edition])

  async function startCamera() {
    setCameraMessage('')
    const DetectorClass = (window as DetectorWindow).BarcodeDetector
    if (!DetectorClass) { setCameraMessage('Questo browser non offre la lettura QR automatica. Puoi inserire il codice manualmente.'); return }
    try {
      const media = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false })
      stream.current = media; setCameraOn(true)
      if (video.current) { video.current.srcObject = media; await video.current.play() }
      const detector = new DetectorClass({ formats: ['qr_code'] })
      const scanFrame = async () => {
        const element = video.current
        if (!element || !stream.current) return
        try {
          const found = await detector.detect(element)
          if (found[0]?.rawValue) { setTicketRef(found[0].rawValue); setCameraMessage('QR letto. Verifica lo stand e conferma la registrazione.'); stopCamera(); return }
        } catch { setCameraMessage('Lettura non riuscita: mantieni il QR al centro dell’inquadratura.') }
        frame.current = requestAnimationFrame(() => void scanFrame())
      }
      frame.current = requestAnimationFrame(() => void scanFrame())
    } catch {
      setCameraMessage('Fotocamera non disponibile o permesso negato. Puoi inserire il codice manualmente.')
    }
  }

  function stopCamera() {
    if (frame.current != null) cancelAnimationFrame(frame.current)
    stream.current?.getTracks().forEach((track) => track.stop())
    stream.current = null; setCameraOn(false)
  }

  function connect(event: FormEvent) {
    event.preventDefault()
    saveToken('internal', tokenInput.trim())
    setError('')
  }

  async function submit(event: FormEvent) {
    event.preventDefault(); setError(''); setResult(null); setSending(true); stopCamera()
    try {
      const response = await api<ScanResult>('/scansioni', {
        method: 'POST',
        body: JSON.stringify({
          eventId: crypto.randomUUID(), edizione: Number(edition), codiceStand: stand.trim(), operatoreId: operator.trim(),
          rilevataIl: new Date().toISOString(), ticketRef: ticketRef.trim(),
          consensoEspositori: consentExhibitors, ...(leadMagnetId ? { idLeadMagnet: Number(leadMagnetId) } : {}), ...(shareContact ? { email: email.trim() } : {}),
        }),
      }, 'internal')
      setResult(response); setTicketRef(''); setEmail(''); setShareContact(false); setConsentExhibitors(false); setLeadMagnetId('')
    } catch (reason) {
      setError(reason instanceof ApiError && reason.status === 401 ? 'Token non valido o scaduto. Ricollega un token operatore.' : reason instanceof Error ? reason.message : 'Invio non riuscito. La scansione resta nel modulo per consentire un nuovo tentativo.')
    } finally { setSending(false) }
  }

  return <section className="scan-page">
    <div className="page-heading"><div><p className="eyebrow">OPERATIVITÀ · 06</p><h2>Scansione allo stand</h2><p className="intro">Registra una visita in pochi secondi. Nessun nome del visitatore viene mostrato.</p></div><span className="live-indicator"><i /> PRONTO AL CHECK-IN</span></div>

    <form className="access-strip" onSubmit={connect}><label htmlFor="scan-token">Token operatore</label><input id="scan-token" type="password" autoComplete="off" value={tokenInput} onChange={(event) => setTokenInput(event.target.value)} placeholder="Token staff o dispositivo" /><button className="button button--dark">Collega</button><span>Conservato solo nella scheda corrente.</span></form>
    {error && <p className="alert alert--error" role="alert">{error}</p>}

    <div className="scan-layout">
      <div className="scan-stage">
        <div className="scan-topline"><span>LETTORE QR</span><span className={`reader-state ${cameraOn ? 'reader-state--active' : ''}`}><i /> {cameraOn ? 'FOTOCAMERA ATTIVA' : 'IN ATTESA'}</span></div>
        <div className={`camera-window ${cameraOn ? 'camera-window--active' : ''}`}>
          <video ref={video} muted playsInline aria-label="Anteprima della fotocamera per leggere un QR" />
          {!cameraOn && <div className="camera-placeholder"><div className="qr-symbol"><span /><span /><span /><span /></div><p>Inquadra il QR del visitatore</p><small>oppure inserisci il codice manualmente</small></div>}
          {cameraOn && <div className="scan-frame" aria-hidden="true"><i /><i /><i /><i /></div>}
        </div>
        {cameraMessage && <p className="camera-message" role="status">{cameraMessage}</p>}
        <button className="button button--lime button--wide" type="button" onClick={() => cameraOn ? stopCamera() : void startCamera()}>{cameraOn ? 'Spegni fotocamera' : 'Attiva fotocamera'}</button>
        <p className="privacy-note"><span>✦</span> Il codice QR non viene mostrato a schermo dopo l’invio né salvato nel browser.</p>
      </div>

      <form className="scan-form panel" onSubmit={(event) => void submit(event)}>
        <div className="panel-heading"><div><p className="eyebrow">NUOVA VISITA</p><h3>Dettagli scansione</h3></div><span className="scan-number">01</span></div>
        <div className="form-row"><label>Edizione<select value={edition} onChange={(event) => setEdition(event.target.value)}><option>2026</option><option>2025</option><option>2024</option></select></label><label>Stand<input required value={stand} onChange={(event) => setStand(event.target.value.toUpperCase())} placeholder="Es. A-014" maxLength={20} /></label></div>
        <label>Identificativo operatore<input required value={operator} onChange={(event) => setOperator(event.target.value)} placeholder="ID assegnato allo staff" maxLength={80} /></label>
        <label>Codice QR visitatore<input required value={ticketRef} onChange={(event) => setTicketRef(event.target.value)} placeholder="Scansiona o digita il codice" autoComplete="off" maxLength={240} /></label>
        <label>Lead magnet promosso allo stand<select value={leadMagnetId} onChange={(event) => setLeadMagnetId(event.target.value)}><option value="">Nessuno</option>{leadMagnets.map((item) => <option key={item.id} value={item.id}>{item.titolo} · {item.tipo}</option>)}</select></label>

        <div className="consent-box"><div><strong>Condivisione del contatto</strong><p>Facoltativa. Chiedi il consenso prima di raccogliere un’email.</p></div><label className="toggle"><input type="checkbox" checked={shareContact} onChange={(event) => { setShareContact(event.target.checked); if (!event.target.checked) setConsentExhibitors(false) }} /><span /></label></div>
        {shareContact && <div className="consent-details"><label>Email<input type="email" required value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="off" /></label><label className="consent-check"><input type="checkbox" required checked={consentExhibitors} onChange={(event) => setConsentExhibitors(event.target.checked)} /> Il visitatore acconsente alla condivisione dei dati con l’espositore.</label></div>}

        <button className="button button--dark button--wide" type="submit" disabled={sending || !readToken('internal') || (shareContact && !consentExhibitors)}>{sending ? 'Invio in corso…' : 'Registra visita'}<span aria-hidden="true">↗</span></button>
        <p className="form-note">La seconda scansione dello stesso codice allo stesso stand non incrementa il conteggio. L’esito è deciso dall’API.</p>
      </form>
    </div>

    {result && <section className={`scan-result ${result.duplicata ? 'scan-result--duplicate' : ''}`} aria-live="polite"><div className="result-icon">{result.duplicata ? '↺' : '✓'}</div><div><p className="eyebrow">{result.duplicata ? 'DUPLICATO RICONOSCIUTO' : 'VISITA REGISTRATA'}</p><h3>{result.messaggio ?? 'Scansione acquisita.'}</h3><p>Stand {stand} · Conteggio aggiornato dall’API</p></div><strong>{result.conteggioStand}<small>visite</small></strong></section>}
    <p className="screen-footnote">In caso di rete assente, l’evento non viene salvato localmente: riprova l’invio quando la connessione torna disponibile.</p>
  </section>
}
