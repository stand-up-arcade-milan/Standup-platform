type ProbeResult = {
  status: string
  detail: string
}

type ActuatorHealth = {
  status?: string
  components?: {
    db?: { status?: string }
  }
}

/** Read a JSON health endpoint and turn network/HTTP failures into visible status. */
async function readProbe(path: string, selectStatus?: (body: ActuatorHealth) => string | undefined): Promise<ProbeResult> {
  try {
    const response = await fetch(path)
    if (!response.ok) {
      return { status: 'DOWN', detail: `HTTP ${response.status}` }
    }

    const body = (await response.json()) as ActuatorHealth
    return {
      status: selectStatus?.(body) ?? body.status ?? 'UNKNOWN',
      detail: path,
    }
  } catch {
    return { status: 'DOWN', detail: 'Servizio non raggiungibile' }
  }
}

/** The same-origin paths are forwarded by Vite to the backend container. */
export async function loadServiceHealth() {
  const [api, database] = await Promise.all([
    readProbe('/api/v1/health'),
    readProbe('/actuator/health', (body) => body.components?.db?.status),
  ])

  return { api, database }
}
