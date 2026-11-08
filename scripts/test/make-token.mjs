import { createHmac } from 'node:crypto'

const role = process.argv[2]
const allowed = new Set(['COMMERCIALE', 'STAFF', 'AMMINISTRATORE', 'DIREZIONE', 'DEVICE', 'BAD', 'ESPOSITORE'])
if (!allowed.has(role)) throw new Error('Specificare un ruolo valido per il token di test.')
const secret = process.env.ARCADE_JWT_SECRET ?? 'local-development-secret-change-me-32-bytes'
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url')
const now = Math.floor(Date.now() / 1000)
const content = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({ sub: `ci-${role.toLowerCase()}`, role, iat: now, exp: now + 3600 })}`
process.stdout.write(`${content}.${createHmac('sha256', secret).update(content).digest('base64url')}`)
