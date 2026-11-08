package standup.api;

import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.transaction.annotation.Transactional;
import org.postgresql.util.PGobject;

/** PostgreSQL-backed implementation of the routes listed in docs/openapi.yaml. */
@RestController
@RequestMapping("/api/v1")
public class PlatformApiController {
    private final JdbcTemplate db;
    private final ApiTokens tokens;
    private final LoginRateLimiter loginRateLimiter;
    private final CommercialDocumentService commercialDocuments;
    private final SecureRandom random = new SecureRandom();

    @Autowired
    public PlatformApiController(JdbcTemplate db, ApiTokens tokens, LoginRateLimiter loginRateLimiter,
            CommercialDocumentService commercialDocuments) {
        this.db = db;
        this.tokens = tokens;
        this.loginRateLimiter = loginRateLimiter;
        this.commercialDocuments = commercialDocuments;
    }

    PlatformApiController(JdbcTemplate db, ApiTokens tokens) {
        this(db, tokens, new LoginRateLimiter(), new CommercialDocumentService());
    }

    @Transactional
    @RequestMapping(value = {"", "/**"}, method = {RequestMethod.GET, RequestMethod.POST, RequestMethod.PATCH, RequestMethod.PUT})
    public ResponseEntity<?> dispatch(HttpServletRequest request, @RequestBody(required = false) Map<String, Object> body) {
        String path = request.getRequestURI().substring(request.getContextPath().length());
        path = path.substring("/api/v1".length());
        if (path.isEmpty()) path = "/";
        String method = request.getMethod();
        Map<String, Object> input = body == null ? Map.of() : body;
        try {
            boolean health = path.equals("/health");
            if (!health) db.execute("SET LOCAL ROLE arcade_api");
            authorize(path, method, request);
            String databaseRole = databaseRole(path, method, request);
            Map<String, Object> actor = actorClaims(request);
            if ("arcade_espositore".equals(databaseRole)) {
                Object exhibitorId = actor.get("idEspositore");
                if (!(exhibitorId instanceof String id) || id.isBlank()) {
                    throw new ApiFailure(403, "ESPOSITORE_NON_ASSOCIATO", "The exhibitor token has no exhibitor identifier.");
                }
                db.queryForObject("SELECT set_config('arcade.id_espositore', ?, true)", String.class, id);
            }
            if (!health && !"arcade_api".equals(databaseRole)) {
                db.execute("SET LOCAL ROLE " + databaseRole);
            }
            Object result = execute(path, method, request, input);
            int status = status(method, path, result);
            auditSuccess(path, method, actor, databaseRole);
            if (result instanceof ResponseEntity<?> response) return response;
            Object shaped = camelize(result);
            return result == null ? ResponseEntity.status(status).build() : ResponseEntity.status(status).body(shaped);
        } catch (ApiFailure failure) {
            throw failure;
        } catch (DataIntegrityViolationException conflict) {
            throw new ApiFailure(409, "CONFLITTO_DATI", "L'operazione viola un vincolo o una risorsa è già occupata.");
        } catch (IllegalArgumentException invalid) {
            throw new ApiFailure(400, "DATI_NON_VALIDI", invalid.getMessage());
        }
    }

    private int status(String method, String path, Object result) {
        if (path.equals("/auth/login") || path.equals("/auth/invito/accetta")) return 200;
        if (path.equals("/auth/password/recupero")) return 202;
        if (path.equals("/auth/password/reimposta")) return 204;
        if (path.equals("/scansioni") && result instanceof Map<?, ?> map && Boolean.TRUE.equals(map.get("duplicata"))) return 200;
        if (path.startsWith("/integrazioni/bad/kpi/") && result instanceof Map<?, ?> map && "GIA_RICEVUTO".equals(map.get("stato"))) return 200;
        if ("POST".equals(method)) return 201;
        if ("PUT".equals(method) && path.startsWith("/integrazioni/bad/kpi/")) return 201;
        if ("PUT".equals(method) && path.startsWith("/admin/edizioni/")) return 200;
        return 200;
    }

    /** Selects a fixed database role after HTTP authorization; never derived from request text. */
    private String databaseRole(String path, String method, HttpServletRequest request) {
        if (path.startsWith("/auth/")) return "arcade_autenticazione";
        if (path.equals("/visitatori/registrazioni") || path.matches("/visitatori/registrazioni/[^/]+/consensi")) return "arcade_registrazione";
        if (path.startsWith("/richieste/") && "POST".equals(method)) return "arcade_scrittura_pubblica";
        if (path.equals("/richieste") && "GET".equals(method)) return "arcade_dati_personali";
        if (path.startsWith("/bi/dati/") || path.startsWith("/integrazioni/bad/")) return "arcade_bad";
        if (path.equals("/accessi") || path.equals("/scansioni") || path.startsWith("/pedane/")
                || path.startsWith("/sensori-ai/") || path.equals("/rilevazioni/peso")) return "arcade_dispositivo";
        if (path.equals("/admin/audit") && "GET".equals(method)) return "arcade_audit_reader";

        Map<String, Object> claims = actorClaims(request);
        boolean exhibitor = "ESPOSITORE".equals(claims.get("role"));
        if (exhibitor && (path.startsWith("/espositori/me") || path.equals("/stand")
                || path.matches("/pratiche/[0-9a-fA-F-]{36}/documenti(?:/[0-9a-fA-F-]{36}/download)?"))) return "arcade_espositore";

        if (path.equals("/edizioni") || path.equals("/padiglioni")
                || (path.equals("/mappa") && !Boolean.parseBoolean(request.getParameter("includiAffollamento")))
                || path.equals("/espositori") || path.equals("/espositori/categorie")
                || (path.matches("/espositori/[^/]+$") && !path.equals("/espositori/me"))
                || (path.equals("/lead-magnet") && "GET".equals(method))
                || (path.equals("/avvisi") && "GET".equals(method)
                    && "VISITATORI".equals(request.getParameter("pubblico")))) return "arcade_pubblico";
        return "arcade_api";
    }

    private Map<String, Object> actorClaims(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || authorization.isBlank()
                || !authorization.toLowerCase(java.util.Locale.ROOT).startsWith("bearer ")) return Map.of();
        return tokens.authenticate(request, "ESPOSITORE", "COMMERCIALE", "STAFF", "AMMINISTRATORE", "DIREZIONE", "DEVICE", "BAD");
    }

    private void auditSuccess(String path, String method, Map<String, Object> actor, String restoreRole) {
        if (!audited(path, method)) return;
        String subject = actor.get("sub") instanceof String value ? value : null;
        String role = actor.get("role") instanceof String value ? value : "PUBBLICO";
        String actorRef = subject == null ? null : tokens.fingerprint("audit|" + subject);
        db.execute("SET LOCAL ROLE arcade_audit_writer");
        db.update("INSERT INTO arcade.audit_event(actor_ref,actor_role,action,resource) VALUES(?,?,?,?)",
                actorRef, role, method, auditResource(path));
        db.execute("SET LOCAL ROLE " + restoreRole);
    }

    private boolean audited(String path, String method) {
        return path.startsWith("/admin/") || path.startsWith("/auth/")
                || path.equals("/richieste") || path.startsWith("/richieste/")
                || path.startsWith("/visitatori/registrazioni")
                || path.startsWith("/espositori/me") || path.startsWith("/pratiche/")
                || path.equals("/pratiche") || path.equals("/accessi") || path.equals("/scansioni")
                || path.startsWith("/bi/dati/") || path.startsWith("/integrazioni/bad/");
    }

    private String auditResource(String path) {
        if (path.matches("/pratiche/[0-9a-fA-F-]{36}/documenti/[0-9a-fA-F-]{36}/download")) {
            return "/pratiche/{id}/documenti/{id}/download";
        }
        if (path.matches("/pratiche/[0-9a-fA-F-]{36}.*")) return path.replaceFirst("/pratiche/[0-9a-fA-F-]{36}", "/pratiche/{id}");
        if (path.matches("/avvisi/[0-9a-fA-F-]{36}")) return "/avvisi/{id}";
        if (path.matches("/visitatori/registrazioni/[^/]+/consensi")) return "/visitatori/registrazioni/{id}/consensi";
        return path;
    }

    private void authorize(String path, String method, HttpServletRequest request) {
        if (path.equals("/health") || path.equals("/edizioni") || path.equals("/padiglioni")
                || path.equals("/espositori") || path.equals("/espositori/categorie") || (path.matches("/espositori/[^/]+$") && !path.equals("/espositori/me"))
                || path.startsWith("/richieste/espositore") || path.startsWith("/richieste/visitatore")
                || path.equals("/visitatori/registrazioni") || path.matches("/visitatori/registrazioni/[^/]+/consensi") || path.startsWith("/auth/")) return;
        if (path.equals("/mappa")) {
            if (Boolean.parseBoolean(request.getParameter("includiAffollamento"))) {
            tokens.authenticate(request, "DIREZIONE", "AMMINISTRATORE");
            }
            return;
        }
        if (path.equals("/stand")) { tokens.authenticate(request, "COMMERCIALE", "STAFF", "AMMINISTRATORE", "ESPOSITORE"); return; }
        if (path.equals("/listino")) { tokens.authenticate(request, "COMMERCIALE", "AMMINISTRATORE"); return; }
        if (path.startsWith("/espositori/me")) { tokens.authenticate(request, "ESPOSITORE"); return; }
        if (path.equals("/richieste") || path.equals("/pratiche")) { tokens.authenticate(request,"COMMERCIALE","AMMINISTRATORE"); return; }
        if (path.startsWith("/pratiche/")) {
            if("GET".equals(method)&&path.matches("/pratiche/[0-9a-fA-F-]{36}/documenti(?:/[0-9a-fA-F-]{36}/download)?")) {
                Map<String,Object> claims=tokens.authenticate(request,"COMMERCIALE","AMMINISTRATORE","ESPOSITORE");
                if("ESPOSITORE".equals(claims.get("role"))) assertPracticeOwner(path.split("/")[2],claims);
            } else tokens.authenticate(request,"COMMERCIALE","AMMINISTRATORE");
            return;
        }
        if (path.equals("/accessi")) { tokens.authenticate(request, "DEVICE", "STAFF", "AMMINISTRATORE"); return; }
        if (path.equals("/scansioni")) { tokens.authenticate(request, "DEVICE", "STAFF", "ESPOSITORE"); return; }
        if (path.startsWith("/pedane/") || path.startsWith("/sensori-ai/") || path.equals("/rilevazioni/peso")) { tokens.authenticate(request, "DEVICE"); return; }
        if (path.equals("/lead-magnet") && "GET".equals(method)) {
            return;
        }
        if (path.equals("/lead-magnet")) { tokens.authenticate(request, "COMMERCIALE", "AMMINISTRATORE"); return; }
        if (path.equals("/avvisi") && "GET".equals(method)) {
            String audience=request.getParameter("pubblico");
            if(audience==null) { tokens.authenticate(request,"STAFF","AMMINISTRATORE"); return; }
            if(audience.equals("VISITATORI")) return;
            if(audience.equals("ESPOSITORI")) { tokens.authenticate(request,"ESPOSITORE"); return; }
            if(audience.equals("STAFF")) { tokens.authenticate(request,"STAFF","AMMINISTRATORE"); return; }
            throw new ApiFailure(400,"DESTINATARIO_NON_VALIDO","Il destinatario dell’avviso non è valido.");
        }
        if (path.startsWith("/kpi/")) {
            if(path.matches("/kpi/stand/[^/]+")||path.matches("/kpi/espositori/[^/]+")) tokens.authenticate(request,"DIREZIONE","COMMERCIALE","ESPOSITORE","AMMINISTRATORE");
            else tokens.authenticate(request,"DIREZIONE","COMMERCIALE","AMMINISTRATORE");
            return;
        }
        if (path.equals("/avvisi") || path.startsWith("/avvisi/")) { tokens.authenticate(request, "STAFF", "AMMINISTRATORE"); return; }
        if (path.startsWith("/admin/")) { tokens.authenticate(request, "AMMINISTRATORE"); return; }
        if (path.startsWith("/bi/dati/")) { tokens.authenticate(request, "BAD"); return; }
        if (path.startsWith("/integrazioni/bad/")) { tokens.authenticate(request, "BAD"); return; }
        throw new ApiFailure(404, "ROTTA_NON_TROVATA", "La rotta non è definita nel contratto API.");
    }

    private Object execute(String p, String m, HttpServletRequest r, Map<String, Object> b) {
        if (p.equals("/health")) return map("service", "standup-platform-api", "status", "UP");
        if (p.equals("/admin/audit") && m.equals("GET")) return auditEvents(r);
        if (p.equals("/edizioni") && m.equals("GET")) return items(db.queryForList("SELECT anno, sede, inizio_vendite, inizio_fiera, fine_fiera, stato FROM arcade.edizione WHERE (?::boolean IS NULL OR (? AND stato='ATTIVA') OR (NOT ? AND stato<>'ATTIVA')) ORDER BY anno DESC", bool(r, "attiva"), bool(r, "attiva"), bool(r, "attiva")));
        if (p.equals("/padiglioni") && m.equals("GET")) return padiglioni(edition(r));
        if (p.equals("/stand") && m.equals("GET")) return stand(r);
        if (p.equals("/listino") && m.equals("GET")) return listino(r);
        if (p.equals("/mappa") && m.equals("GET")) return mappa(r);
        if (p.equals("/espositori") && m.equals("GET")) return espositori(r);
        if (p.equals("/espositori/categorie") && m.equals("GET")) return items(db.queryForList("SELECT c.codice, c.nome, count(ec.id_espositore)::integer AS conteggio FROM arcade.categoria_espositore c LEFT JOIN arcade.espositore_categoria ec ON ec.codice_categoria=c.codice GROUP BY c.codice,c.nome ORDER BY c.nome"));
        if (p.matches("/espositori/[^/]+$") && !p.equals("/espositori/me") && m.equals("GET")) return espositorePubblico(p.substring(p.lastIndexOf('/') + 1));
        if (p.equals("/espositori/me") && m.equals("GET")) return mioProfilo(r, edition(r));
        if (p.equals("/espositori/me/contratto") && m.equals("GET")) return mioContratto(r, edition(r));
        if (p.equals("/espositori/me/contatti") && m.equals("GET")) return contatti(r, edition(r));
        if (p.equals("/espositori/me/presenze-peso") && m.equals("GET")) return presenzePeso(r, edition(r));
        if (p.equals("/richieste/espositore") && m.equals("POST")) return createRichiestaEspositore(b);
        if (p.equals("/richieste/visitatore") && m.equals("POST")) return createRichiestaVisitatore(b);
        if (p.equals("/visitatori/registrazioni") && m.equals("POST")) return createRegistrazione(b);
        if (p.matches("/visitatori/registrazioni/[^/]+/consensi") && m.equals("PATCH")) return updateConsensi(p, b);
        if (p.equals("/auth/login") && m.equals("POST")) return login(r,b);
        if (p.equals("/auth/invito/accetta") && m.equals("POST")) return acceptInvite(b);
        if (p.equals("/auth/password/recupero") && m.equals("POST")) return requestRecovery(b);
        if (p.equals("/auth/password/reimposta") && m.equals("POST")) return resetPassword(b);
        if (p.equals("/auth/google") && m.equals("POST")) return googleAuth(b);
        if (p.equals("/auth/microsoft") && m.equals("POST")) return microsoftAuth(b);
        if (p.equals("/richieste") && m.equals("GET")) return richieste(r);
        if (p.equals("/pratiche") && m.equals("GET")) return pratiche(r);
        if (p.equals("/pratiche") && m.equals("POST")) return createPratica(r, b);
        if (p.matches("/pratiche/[^/]+$")) return pratica(p.substring(p.lastIndexOf('/') + 1), m, b);
        if (p.matches("/pratiche/[^/]+/stato") && m.equals("PATCH")) return updateStato(p, b);
        if (p.matches("/pratiche/[^/]+/offerta") && m.equals("POST")) return createOfferta(p, b);
        if (p.matches("/pratiche/[^/]+/documenti/[^/]+/download") && m.equals("GET")) return downloadDocument(p);
        if (p.matches("/pratiche/[^/]+/documenti") && m.equals("GET")) return documenti(p);
        if (p.matches("/pratiche/[^/]+/acconti") && m.equals("POST")) return createAcconto(p, b);
        if (p.matches("/pratiche/[^/]+/rinnovo") && m.equals("POST")) return rinnovo(p);
        if (p.equals("/accessi") && m.equals("POST")) return createAccesso(b);
        if (p.equals("/scansioni") && m.equals("POST")) return createScansione(r,b);
        if (p.equals("/pedane/conteggi") && m.equals("POST")) return createConteggio(b, "PEDANA");
        if (p.equals("/sensori-ai/conteggi") && m.equals("POST")) return createConteggio(b, "SENSORE_AI");
        if (p.equals("/rilevazioni/peso") && m.equals("POST")) return createConteggio(b, "PESO");
        if (p.equals("/lead-magnet") && m.equals("GET")) return leadMagnets(r);
        if (p.equals("/lead-magnet") && m.equals("POST")) return createLeadMagnet(b);
        if (p.startsWith("/kpi/")) return kpi(p, r);
        if (p.equals("/avvisi") && m.equals("GET")) return avvisi(r);
        if (p.equals("/avvisi") && m.equals("POST")) return createAvviso(b);
        if (p.matches("/avvisi/[^/]+") && m.equals("PATCH")) return updateAvviso(p, b);
        if (p.matches("/admin/edizioni/\\d+") && m.equals("PUT")) return putEdizione(p, b);
        if (p.matches("/admin/edizioni/\\d+/parametri") && m.equals("PATCH")) return updateParametri(p, b);
        if (p.startsWith("/bi/dati/")) return exportBi(p, r);
        if (p.matches("/integrazioni/bad/kpi/[^/]+") && m.equals("PUT")) return receiveKpi(p, b);
        throw new ApiFailure(404, "ROTTA_NON_TROVATA", "La rotta non è definita nel contratto API.");
    }

    private Object padiglioni(Integer year) {
        return items(db.queryForList("""
                SELECT p.codice, p.nome, NULL::integer AS capienza,
                       COALESCE(sum(s.superficie_mq),0)::numeric AS superficie_mq,
                       COALESCE(array_agg(DISTINCT v.codice) FILTER (WHERE v.codice IS NOT NULL),ARRAY[]::text[]) AS varchi
                FROM arcade.padiglione p LEFT JOIN arcade.stand s ON s.padiglione=p.codice
                LEFT JOIN arcade.varco v ON v.padiglione=p.codice GROUP BY p.codice,p.nome ORDER BY p.codice
                """));
    }

    private Object stand(HttpServletRequest r) {
        int year = edition(r);
        String ownExhibitor=null;
        if(r.getHeader("Authorization")!=null) {
            Map<String,Object> claims=tokens.authenticate(r,"COMMERCIALE","STAFF","AMMINISTRATORE","ESPOSITORE");
            if("ESPOSITORE".equals(claims.get("role"))) ownExhibitor=String.valueOf(claims.get("idEspositore"));
        }
        return items(db.queryForList("""
                SELECT s.codice, COALESCE(ps.padiglione,s.padiglione) AS padiglione,
                       COALESCE(ps.superficie_mq,s.superficie_mq) AS superficie_mq,
                       CASE WHEN NOT s.disponibile THEN 'NON_DISPONIBILE' WHEN a.codice_stand IS NULL THEN 'LIBERO' ELSE 'ASSEGNATO' END AS stato,
                       ps.posizione AS posizione_mappa, NULL::numeric AS prezzo_listino_eur
                FROM arcade.stand s LEFT JOIN arcade.planimetria_stand ps ON ps.codice_stand=s.codice AND ps.anno=?
                LEFT JOIN arcade.assegnazione_stand a ON a.codice_stand=s.codice AND a.anno=?
                WHERE (?::text IS NULL OR COALESCE(ps.padiglione,s.padiglione)=?) AND (?::text IS NULL OR a.id_espositore=?)
                  AND (?::text IS NULL OR CASE WHEN NOT s.disponibile THEN 'NON_DISPONIBILE' WHEN a.codice_stand IS NULL THEN 'LIBERO' ELSE 'ASSEGNATO' END=?)
                ORDER BY COALESCE(ps.padiglione,s.padiglione),s.codice
                """, year, year, r.getParameter("padiglione"), r.getParameter("padiglione"), ownExhibitor, ownExhibitor, r.getParameter("stato"), r.getParameter("stato")));
    }

    private Object listino(HttpServletRequest r) {
        int year=edition(r);
        return items(db.queryForList("SELECT codice_voce,descrizione,tipo,unita,prezzo_eur,disponibilita_sorgente,nota_sorgente FROM arcade.listino_voce WHERE anno=? ORDER BY tipo,descrizione",year));
    }

    private Object mappa(HttpServletRequest r) {
        int year = edition(r);
        List<Map<String, Object>> pavilions = castItems(padiglioni(year));
        List<Map<String, Object>> booths = castItems(stand(r));
        List<Map<String,Object>> mapAreas=new ArrayList<>();
        for(Map<String,Object> pavilion:pavilions) {
            String code=String.valueOf(pavilion.get("codice"));
            mapAreas.add(map("padiglione",pavilion,
                    "stands",booths.stream().filter(item->code.equals(item.get("padiglione"))).toList(),
                    "varchi",pavilion.get("varchi")));
        }
        boolean crowd = Boolean.parseBoolean(r.getParameter("includiAffollamento"));
        List<Map<String, Object>> density = crowd ? db.queryForList("SELECT codice,valore,unita,edizione,periodo_dal,periodo_al,dimensioni,fonte,qualita,flag_qualita,stimato,simulato,nota,calcolato_il,formula_versione FROM arcade.v_mappa_affollamento WHERE edizione=? ORDER BY calcolato_il DESC", year) : List.of();
        return map("edizione", year, "padiglioni", mapAreas, "affollamento", density);
    }

    private Object espositori(HttpServletRequest r) {
        int year = edition(r), limit = limit(r), offset = cursor(r);
        String q = r.getParameter("q");
        List<Map<String, Object>> rows = db.queryForList("""
                SELECT p.id_espositore AS id, p.nome_pubblico, p.descrizione, p.logo_url, p.sito_web, p.in_evidenza,
                       COALESCE(jsonb_agg(DISTINCT jsonb_build_object('codice',c.codice,'nome',c.nome)) FILTER (WHERE c.codice IS NOT NULL),'[]'::jsonb) AS categorie,
                       COALESCE(a.codice_stand, ps.codice_stand) AS codice_stand
                FROM arcade.profilo_espositore p LEFT JOIN arcade.espositore_categoria ec ON ec.id_espositore=p.id_espositore
                LEFT JOIN arcade.categoria_espositore c ON c.codice=ec.codice_categoria
                LEFT JOIN arcade.assegnazione_stand a ON a.id_espositore=p.id_espositore AND a.anno=?
                LEFT JOIN arcade.planimetria_stand ps ON ps.codice_stand=a.codice_stand AND ps.anno=?
                WHERE (?::text IS NULL OR p.nome_pubblico ILIKE '%'||?||'%')
                  AND (cardinality(?::text[]) = 0 OR EXISTS (SELECT 1 FROM arcade.espositore_categoria ecat WHERE ecat.id_espositore=p.id_espositore AND ecat.codice_categoria=ANY(?::text[])))
                GROUP BY p.id_espositore,p.nome_pubblico,p.descrizione,p.logo_url,p.sito_web,p.in_evidenza,a.codice_stand,ps.codice_stand
                ORDER BY p.nome_pubblico LIMIT ? OFFSET ?
                """, year, year, q, q, r.getParameterValues("categorie")==null?new String[0]:r.getParameterValues("categorie"), r.getParameterValues("categorie")==null?new String[0]:r.getParameterValues("categorie"), limit + 1, offset);
        return page(rows, limit, offset);
    }

    private Object espositorePubblico(String id) {
        Map<String, Object> row = one("""
                SELECT p.id_espositore AS id,p.nome_pubblico,p.descrizione,p.logo_url,p.sito_web,p.in_evidenza,
                       COALESCE(jsonb_agg(DISTINCT jsonb_build_object('codice',c.codice,'nome',c.nome)) FILTER (WHERE c.codice IS NOT NULL),'[]'::jsonb) AS categorie
                FROM arcade.profilo_espositore p LEFT JOIN arcade.espositore_categoria ec ON ec.id_espositore=p.id_espositore
                LEFT JOIN arcade.categoria_espositore c ON c.codice=ec.codice_categoria WHERE p.id_espositore=?
                GROUP BY p.id_espositore,p.nome_pubblico,p.descrizione,p.logo_url,p.sito_web,p.in_evidenza
                """, id);
        row.put("stand", db.queryForList("SELECT codice,padiglione,superficie_mq,'ASSEGNATO' AS stato FROM arcade.assegnazione_stand a JOIN arcade.stand s ON s.codice=a.codice_stand WHERE a.id_espositore=? ORDER BY anno DESC LIMIT 1", id).stream().findFirst().orElse(null));
        return row;
    }

    private Object mioProfilo(HttpServletRequest r, int year) {
        String id = String.valueOf(tokens.authenticate(r, "ESPOSITORE").get("idEspositore"));
        Map<String, Object> profile = one("SELECT e.id_espositore AS id,e.ragione_sociale,?::integer AS edizione,p.livello AS pacchetto FROM arcade.espositore e LEFT JOIN arcade.pacchetto_espositore p ON p.id_espositore=e.id_espositore AND p.anno=? WHERE e.id_espositore=?", year, year, id);
        profile.put("stand", db.queryForList("SELECT a.codice_stand AS codice,s.padiglione,s.superficie_mq,'ASSEGNATO' AS stato FROM arcade.assegnazione_stand a JOIN arcade.stand s ON s.codice=a.codice_stand WHERE a.anno=? AND a.id_espositore=?", year, id).stream().findFirst().orElse(null));
        return profile;
    }

    private Object mioContratto(HttpServletRequest r, int year) {
        String id = String.valueOf(tokens.authenticate(r, "ESPOSITORE").get("idEspositore"));
        Map<String, Object> contract = oneOrNull("SELECT p.anno AS edizione,p.stato,p.pacchetto,p.codice_stand,v.totale_eur, v.acconti_eur,p.id_pratica FROM arcade.pratica p LEFT JOIN arcade.v_pratica v USING(id_pratica) WHERE p.anno=? AND p.id_espositore=? ORDER BY p.creata_il DESC LIMIT 1", year, id);
        if (contract == null) throw new ApiFailure(404, "CONTRATTO_NON_TROVATO", "Nessun contratto disponibile per l'edizione.");
        Object practiceId = contract.remove("id_pratica");
        contract.put("acconti", db.queryForList("SELECT id_acconto AS id,importo_eur,ricevuto_il,riferimento FROM arcade.acconto WHERE id_pratica=? ORDER BY ricevuto_il", practiceId));
        contract.put("documenti", commercialDocumentRows((UUID) practiceId));
        return contract;
    }

    private Object contatti(HttpServletRequest r, int year) {
        String id = String.valueOf(tokens.authenticate(r, "ESPOSITORE").get("idEspositore"));
        int limit = limit(r), offset = cursor(r);
        return page(db.queryForList("SELECT c.id_contatto AS id,c.anno,c.codice_stand,c.raccolto_il,c.interesse,c.id_lead_magnet,r.email FROM arcade.contatto_stand c JOIN arcade.contatto_riservato r USING(id_contatto) WHERE c.anno=? AND c.id_espositore=? AND c.consenso_espositori AND c.consenso_marketing='SI' AND c.utilizzabile_marketing AND c.fascia_eta IN ('18-24','25-34','35-44','45+') AND c.motivo_esclusione='NESSUNO' AND (c.anno<2026 OR c.id_lead_magnet IS NOT NULL) ORDER BY c.raccolto_il DESC LIMIT ? OFFSET ?", year, id, limit + 1, offset), limit, offset);
    }

    private Object presenzePeso(HttpServletRequest r, int year) {
        String id = String.valueOf(tokens.authenticate(r, "ESPOSITORE").get("idEspositore"));
        Map<String,Object> assignment=oneOrNull("SELECT codice_stand FROM arcade.assegnazione_stand WHERE anno=? AND id_espositore=?",year,id);
        Map<String,Object> packageRow=oneOrNull("SELECT livello FROM arcade.pacchetto_espositore WHERE anno=? AND id_espositore=?",year,id);
        if (packageRow==null||!"PREMIUM".equals(packageRow.get("livello"))) throw new ApiFailure(403, "PACCHETTO_NON_ABILITATO", "La stima delle presenze dal peso è riservata al pacchetto PREMIUM.");
        if (assignment==null) throw new ApiFailure(404,"STAND_NON_TROVATO","Non risulta uno stand assegnato per l'edizione.");
        String stand=String.valueOf(assignment.get("codice_stand"));
        List<Map<String,Object>> estimates=db.queryForList("""
                WITH letture_filtrate AS (
                    SELECT r.anno,r.rilevato_il,date_trunc('minute',r.rilevato_il) AS minuto,
                           greatest(r.peso_lordo_kg-r.tara_kg,0) AS peso_netto,r.fonte,
                           avg(greatest(r.peso_lordo_kg-r.tara_kg,0)) OVER (PARTITION BY r.anno,r.codice_stand ORDER BY r.rilevato_il ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS peso_medio_30s
                    FROM arcade.rilevazione_peso r
                    WHERE r.anno=? AND r.codice_stand=?
                      AND (?::timestamptz IS NULL OR r.rilevato_il>=?)
                      AND (?::timestamptz IS NULL OR r.rilevato_il<=?)
                ), minuto AS (
                    SELECT anno,minuto,avg(peso_medio_30s) AS peso_medio_30s,count(*)::integer AS letture,max(fonte) AS fonte
                    FROM letture_filtrate GROUP BY anno,minuto
                ), confronto AS (
                    SELECT *,lag(peso_medio_30s) OVER (ORDER BY minuto) AS peso_precedente FROM minuto
                )
                SELECT minuto,
                       least(greatest(round(CASE WHEN peso_precedente IS NOT NULL AND abs(peso_medio_30s-peso_precedente)<p.soglia_rumore_kg THEN peso_precedente ELSE peso_medio_30s END/p.peso_medio_kg),0),
                             floor(coalesce(ps.superficie_mq,s.superficie_mq)*p.persone_per_mq))::integer AS presenze_stimate,
                       letture,fonte
                FROM confronto c JOIN arcade.parametri_stima p USING(anno)
                JOIN arcade.stand s ON s.codice=?
                LEFT JOIN arcade.planimetria_stand ps ON ps.anno=c.anno AND ps.codice_stand=s.codice
                ORDER BY minuto
                """,year,stand,r.getParameter("dal"),r.getParameter("dal"),r.getParameter("al"),r.getParameter("al"),stand);
        return map("edizione",year,"codiceStand",stand,"erroreAttesoPercentuale",15,"items",estimates);
    }

    private Object createRichiestaEspositore(Map<String, Object> b) {
        require(b, "azienda", "referente", "email", "categoria", "metriQuadriDesiderati", "consensoPrivacy");
        if (!boolValue(b, "consensoPrivacy")) throw new ApiFailure(400, "CONSENSO_PRIVACY_RICHIESTO", "La richiesta commerciale richiede il consenso privacy.");
        UUID id = db.queryForObject("INSERT INTO arcade.richiesta(tipo,azienda,categoria,metri_quadri_desiderati,note,consenso_privacy) VALUES('ESPOSITORE',?,?,?,?,?) RETURNING id_richiesta", UUID.class, text(b,"azienda"), text(b,"categoria"), decimal(b,"metriQuadriDesiderati"), textOrNull(b,"note"), boolValue(b,"consensoPrivacy"));
        db.update("INSERT INTO arcade.richiesta_riservata(id_richiesta,referente,email) VALUES(?,?,?)", id, text(b,"referente"), text(b,"email"));
        return map("id", id, "stato", "NUOVA", "createdAt", Instant.now().toString());
    }

    private Object createRichiestaVisitatore(Map<String, Object> b) {
        require(b, "email");
        UUID id = db.queryForObject("INSERT INTO arcade.richiesta(tipo,consenso_marketing) VALUES('VISITATORE',?) RETURNING id_richiesta", UUID.class, boolValue(b,"consensoMarketing"));
        db.update("INSERT INTO arcade.richiesta_riservata(id_richiesta,email) VALUES(?,?)", id, text(b,"email"));
        return map("id", id, "stato", "NUOVA", "createdAt", Instant.now().toString());
    }

    private Object createRegistrazione(Map<String, Object> b) {
        require(b, "email", "consensoMarketing", "consensoEspositori");
        String email = text(b,"email");
        String name = textOrNull(b,"nome");
        int year = activeEdition();
        Long id = db.queryForObject("INSERT INTO arcade.registrazione_visitatore(anno,provincia,fascia_eta,consenso_marketing,consenso_espositori) VALUES(?,?,?,?,?) RETURNING id_registrazione", Long.class,
                year, defaultText(b,"provincia","NON_DICHIARATO"), defaultText(b,"fasciaEta","NON_DICHIARATO"), boolValue(b,"consensoMarketing"), boolValue(b,"consensoEspositori"));
        db.update("INSERT INTO arcade.registrazione_riservata(id_registrazione,nome,email) VALUES(?,?,?)", id, name, email);
        Object interests = b.get("interessi");
        if (interests instanceof List<?> list) for (Object interest : list) db.update("INSERT INTO arcade.interesse_visitatore(id_registrazione,interesse) VALUES(?,?) ON CONFLICT DO NOTHING", id, interest);
        String revoke = randomToken();
        db.update("INSERT INTO arcade.revoca_registrazione_visitatore(token_hash,id_registrazione) VALUES(?,?)", tokens.hash(revoke), id);
        return map("id", id, "profilabile", boolValue(b,"consensoMarketing") && !"NON_DICHIARATO".equals(defaultText(b,"fasciaEta","NON_DICHIARATO")), "consensiAggiornatiIl", Instant.now().toString(), "tokenRevoca", revoke);
    }

    private Object updateConsensi(String p, Map<String, Object> b) {
        require(b,"tokenRevoca");
        if (!b.containsKey("consensoMarketing") && !b.containsKey("consensoEspositori")) {
            throw new ApiFailure(400,"CONSENSO_NON_SPECIFICATO","Specificare almeno un consenso da aggiornare.");
        }
        String id = p.split("/")[3];
        Boolean marketing = b.containsKey("consensoMarketing") ? boolValue(b,"consensoMarketing") : null;
        Boolean exhibitors = b.containsKey("consensoEspositori") ? boolValue(b,"consensoEspositori") : null;
        int changed = db.update("UPDATE arcade.registrazione_visitatore r SET consenso_marketing=coalesce(?,r.consenso_marketing),consenso_espositori=coalesce(?,r.consenso_espositori),consensi_aggiornati_il=now() FROM arcade.revoca_registrazione_visitatore t WHERE r.id_registrazione=? AND t.id_registrazione=r.id_registrazione AND t.token_hash=? AND t.usato_il IS NULL", marketing, exhibitors, Long.valueOf(id), tokens.hash(text(b,"tokenRevoca")));
        if (changed == 0) throw new ApiFailure(404,"TOKEN_REVOCA_NON_VALIDO","Token di revoca non valido o registrazione non trovata.");
        Map<String,Object> row=one("UPDATE arcade.registrazione_visitatore SET consensi_aggiornati_il=now() WHERE id_registrazione=? RETURNING consenso_marketing,consenso_espositori,consensi_aggiornati_il,profilabile",Long.valueOf(id));
        db.update("UPDATE arcade.revoca_registrazione_visitatore SET usato_il=now() WHERE token_hash=?",tokens.hash(text(b,"tokenRevoca")));
        return row;
    }

    private Object login(HttpServletRequest request, Map<String, Object> b) {
        require(b,"email","password");
        String email=text(b,"email").trim();
        if(email.length()>320) throw new ApiFailure(400,"EMAIL_NON_VALIDA","L’indirizzo email supera il limite consentito.");
        String rateKey=tokens.fingerprint("login-rate|"+request.getRemoteAddr()+"|"+email.toLowerCase(java.util.Locale.ROOT));
        if(loginRateLimiter.blocked(rateKey)) throw new ApiFailure(429,"TROPPI_TENTATIVI","Troppi tentativi. Riprova più tardi.");
        Map<String,Object> account=oneOrNull("SELECT a.id_espositore,a.password_hash,a.attivo FROM arcade.account_espositore a WHERE lower(a.email)=lower(?)", email);
        if (account==null || !Boolean.TRUE.equals(account.get("attivo")) || !verifyPassword(text(b,"password"),String.valueOf(account.get("password_hash")))) {
            loginRateLimiter.failed(rateKey);
            throw new ApiFailure(401,"CREDENZIALI_NON_VALIDE","Email o password non valide.");
        }
        loginRateLimiter.succeeded(rateKey);
        String exhibitor=String.valueOf(account.get("id_espositore"));
        db.update("UPDATE arcade.account_espositore SET ultimo_accesso=now() WHERE lower(email)=lower(?)",email);
        return tokenResponse(tokens.issue(email,"ESPOSITORE",exhibitor,3600));
    }

    private Object acceptInvite(Map<String, Object> b) {
        require(b,"token","password");
        String hash=tokens.hash(text(b,"token"));
        Map<String,Object> invite=oneOrNull("UPDATE arcade.invito_espositore SET usato_il=now() WHERE token_hash=? AND usato_il IS NULL AND scade_il>now() RETURNING id_espositore,email",hash);
        if(invite==null) throw new ApiFailure(404,"INVITO_NON_VALIDO","Invito non valido, già usato o scaduto.");
        String encoded=hashPassword(text(b,"password"));
        db.update("INSERT INTO arcade.account_espositore(id_espositore,email,password_hash) VALUES(?,?,?)",invite.get("id_espositore"),invite.get("email"),encoded);
        return tokenResponse(tokens.issue(String.valueOf(invite.get("email")),"ESPOSITORE",String.valueOf(invite.get("id_espositore")),3600));
    }

    private Object requestRecovery(Map<String,Object> b) {
        require(b,"email");
        Map<String,Object> a=oneOrNull("SELECT id_account FROM arcade.account_espositore WHERE lower(email)=lower(?) AND attivo",text(b,"email"));
        if(a!=null) {
            String token=randomToken();
            db.update("INSERT INTO arcade.recupero_password(token_hash,id_account,scade_il) VALUES(?,?,now()+interval '30 minutes')",tokens.hash(token),a.get("id_account"));
            // Delivery is intentionally delegated to the configured mail integration; never reveal account existence.
        }
        return ResponseEntity.accepted().body(map("message","Se l'account esiste, riceverai un link."));
    }

    private Object resetPassword(Map<String,Object> b) {
        require(b,"token","password");
        String tokenHash=tokens.hash(text(b,"token"));
        int updated=db.update("WITH consumato AS (UPDATE arcade.recupero_password SET usato_il=now() WHERE token_hash=? AND usato_il IS NULL AND scade_il>now() RETURNING id_account) UPDATE arcade.account_espositore a SET password_hash=?,ultimo_accesso=now() FROM consumato c WHERE c.id_account=a.id_account",tokenHash,hashPassword(text(b,"password")));
        if(updated==0) throw new ApiFailure(409,"TOKEN_RECUPERO_NON_VALIDO","Token di recupero non valido, già usato o scaduto.");
        return null;
    }

    private Object richieste(HttpServletRequest r) {
        int limit=limit(r),offset=cursor(r);
        return page(db.queryForList("SELECT q.id_richiesta AS id,q.tipo,q.stato,q.anno,q.azienda,q.categoria,q.metri_quadri_desiderati,q.note,q.consenso_privacy,q.consenso_marketing,q.creata_il,p.referente,p.email FROM arcade.richiesta q LEFT JOIN arcade.richiesta_riservata p USING(id_richiesta) WHERE (?::text IS NULL OR q.stato=?) ORDER BY q.creata_il LIMIT ? OFFSET ?",r.getParameter("stato"),r.getParameter("stato"),limit+1,offset),limit,offset);
    }

    private Object pratiche(HttpServletRequest r) {
        int year=edition(r), limit=limit(r),offset=cursor(r);
        String exhibitor=null;
        if(r.getHeader("Authorization")!=null) {
            Map<String,Object> claims=tokens.authenticate(r,"COMMERCIALE","AMMINISTRATORE","ESPOSITORE");
            if("ESPOSITORE".equals(claims.get("role"))) exhibitor=String.valueOf(claims.get("idEspositore"));
        }
        return page(db.queryForList("SELECT id_pratica AS id,anno AS edizione,id_espositore,codice_stand,stato,pacchetto,totale_eur,sconto_percentuale,approvazione_richiesta,creata_il AS created_at,aggiornata_il AS updated_at FROM arcade.v_pratica WHERE anno=? AND (?::text IS NULL OR stato=?) AND (?::text IS NULL OR id_espositore=?) AND (?::text IS NULL OR id_espositore=?) ORDER BY creata_il DESC LIMIT ? OFFSET ?",year,r.getParameter("stato"),r.getParameter("stato"),r.getParameter("idEspositore"),r.getParameter("idEspositore"),exhibitor,exhibitor,limit+1,offset),limit,offset);
    }

    private Object createPratica(HttpServletRequest r,Map<String,Object>b) {
        require(b,"edizione","idEspositore","codiceStand","pacchetto");
        UUID id=UUID.randomUUID();
        int year=number(b,"edizione");
        String exhibitor=text(b,"idEspositore"), booth=text(b,"codiceStand");
        if(r.getHeader("Authorization")!=null) {
            Map<String,Object> claims=tokens.authenticate(r,"COMMERCIALE","AMMINISTRATORE","ESPOSITORE");
            if("ESPOSITORE".equals(claims.get("role"))&&!exhibitor.equals(claims.get("idEspositore"))) throw new ApiFailure(403,"ESPOSITORE_DIVERSO","Un espositore può aprire pratiche solo per la propria organizzazione.");
        }
        Map<String,Object> selectedStand=oneOrNull("SELECT disponibile FROM arcade.stand WHERE codice=?",booth);
        if(selectedStand==null) throw new ApiFailure(404,"STAND_NON_TROVATO","Lo stand selezionato non esiste.");
        if(!Boolean.TRUE.equals(selectedStand.get("disponibile"))) throw new ApiFailure(409,"STAND_NON_DISPONIBILE","Lo stand non è disponibile per la vendita.");
        if(db.queryForObject("SELECT count(*) FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=?",Integer.class,year,booth)>0) throw new ApiFailure(409,"STAND_GIA_ASSEGNATO","Lo stand è già assegnato per l'edizione.");
        db.update("INSERT INTO arcade.pratica(id_pratica,anno,id_espositore,codice_stand,pacchetto,sconto_percentuale) VALUES(?,?,?,?,?,?)",id,year,exhibitor,booth,text(b,"pacchetto"),decimalOr(b,"scontoPercentuale",BigDecimal.ZERO));
        insertPracticeLines(id,year,b.get("voci"),booth);
        return practice(id.toString());
    }

    private Object pratica(String id,String method,Map<String,Object>b) {
        UUID uuid=uuid(id);
        if(method.equals("GET")) return practice(id);
        if(method.equals("PATCH")) {
            Map<String,Object> existing=oneOrNull("SELECT id_pratica,anno,stato,id_espositore FROM arcade.pratica WHERE id_pratica=?",uuid);
            if(existing==null) throw notFound("Pratica");
            if(b.keySet().stream().anyMatch(key->List.of("codiceStand","pacchetto","scontoPercentuale","voci").contains(key)) && !List.of("BOZZA","INVIATA").contains(String.valueOf(existing.get("stato")))) throw new ApiFailure(409,"PRATICA_NON_MODIFICABILE","Una pratica firmata non può essere modificata.");
            if(b.containsKey("codiceStand")) {
                String stand=String.valueOf(b.get("codiceStand")); int year=((Number)existing.get("anno")).intValue();
                Map<String,Object> selectedStand=oneOrNull("SELECT disponibile FROM arcade.stand WHERE codice=?",stand);
                if(selectedStand==null) throw new ApiFailure(404,"STAND_NON_TROVATO","Lo stand selezionato non esiste.");
                if(!Boolean.TRUE.equals(selectedStand.get("disponibile"))) throw new ApiFailure(409,"STAND_NON_DISPONIBILE","Lo stand non è disponibile per la vendita.");
                if(db.queryForObject("SELECT count(*) FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=? AND id_espositore<>?",Integer.class,year,stand,existing.get("id_espositore"))>0) throw new ApiFailure(409,"STAND_GIA_ASSEGNATO","Lo stand è già assegnato a un altro espositore.");
                db.update("UPDATE arcade.pratica SET codice_stand=?,aggiornata_il=now() WHERE id_pratica=?",stand,uuid);
            }
            if(b.containsKey("pacchetto")) db.update("UPDATE arcade.pratica SET pacchetto=?,aggiornata_il=now() WHERE id_pratica=?",b.get("pacchetto"),uuid);
            if(b.containsKey("scontoPercentuale")) db.update("UPDATE arcade.pratica SET sconto_percentuale=?,aggiornata_il=now() WHERE id_pratica=?",b.get("scontoPercentuale"),uuid);
            if(b.containsKey("voci")) {
                db.update("DELETE FROM arcade.voce_pratica WHERE id_pratica=?",uuid);
                Map<String,Object> current=one("SELECT anno,codice_stand FROM arcade.pratica WHERE id_pratica=?",uuid);
                if(current.get("codice_stand")==null) throw new ApiFailure(400,"STAND_RICHIESTO","Assegna uno stand prima di calcolare il listino.");
                insertPracticeLines(uuid,((Number)current.get("anno")).intValue(),b.get("voci"),String.valueOf(current.get("codice_stand")));
            }
            return practice(id);
        }
        throw notFound("Rotta pratica");
    }

    private Object updateStato(String p,Map<String,Object>b) {
        require(b,"stato"); UUID id=uuid(p.split("/")[2]);
        Map<String,Object> state=oneOrNull("SELECT stato FROM arcade.pratica WHERE id_pratica=?",id);
        if(state==null) throw notFound("Pratica");
        String old=String.valueOf(state.get("stato")), next=text(b,"stato");
        Map<String,List<String>> transitions=Map.of("BOZZA",List.of("INVIATA"),"INVIATA",List.of("FIRMATA"),"FIRMATA",List.of("ACCONTO_RICEVUTO"),"ACCONTO_RICEVUTO",List.of());
        if(!transitions.getOrDefault(old,List.of()).contains(next)) throw new ApiFailure(409,"TRANSIZIONE_STATO_NON_VALIDA","Transizione di stato non ammessa.");
        db.update("UPDATE arcade.pratica SET stato=?, firmata_il=CASE WHEN ?='FIRMATA' THEN now() ELSE firmata_il END, aggiornata_il=now() WHERE id_pratica=?",next,next,id);
        if ("FIRMATA".equals(next)) archiveContractSummary(id);
        return practice(id.toString());
    }

    private Object createOfferta(String p,Map<String,Object> b) {
        UUID practice=uuid(p.split("/")[2]);
        Map<String,Object> current=oneOrNull("SELECT stato FROM arcade.pratica WHERE id_pratica=?",practice);
        if(current==null) throw notFound("Pratica");
        if(!List.of("BOZZA","INVIATA").contains(String.valueOf(current.get("stato")))) throw new ApiFailure(409,"OFFERTA_NON_MODIFICABILE","L’offerta si può preparare solo prima della firma.");
        require(b,"scontoPercentuale");
        BigDecimal discount=decimal(b,"scontoPercentuale");
        if(discount.signum()<0||discount.compareTo(BigDecimal.valueOf(100))>0) throw new ApiFailure(400,"SCONTO_NON_VALIDO","Lo sconto deve essere compreso tra 0 e 100.");
        db.update("UPDATE arcade.pratica SET sconto_percentuale=?,aggiornata_il=now() WHERE id_pratica=?",discount,practice);
        Map<String,Object> facts = documentFacts(practice);
        byte[] pdf = commercialDocuments.offer(facts, documentLines(practice), textOrNull(b,"note"));
        UUID id = saveCommercialDocument(practice, "OFFERTA", "Offerta " + facts.get("edizione") + " - " + practice + ".pdf", pdf);
        return commercialDocumentRow(id);
    }

    private Object documenti(String p) { UUID id=uuid(p.split("/")[2]); ensurePractice(id); return items(commercialDocumentRows(id)); }

    private void archiveContractSummary(UUID practice) {
        Map<String,Object> facts = documentFacts(practice);
        byte[] pdf = commercialDocuments.contractSummary(facts, documentLines(practice), documentPayments(practice));
        saveCommercialDocument(practice, "ALTRO", "Riepilogo pratica firmata - informativo " + practice + ".pdf", pdf);
    }

    private Map<String,Object> documentFacts(UUID practice) {
        Map<String,Object> facts = one("""
                SELECT p.id_pratica AS id_pratica, p.anno AS edizione, p.id_espositore AS id_espositore,
                       e.ragione_sociale AS ragione_sociale, p.codice_stand AS codice_stand,
                       s.padiglione AS padiglione, coalesce(ps.superficie_mq,s.superficie_mq) AS superficie_mq,
                       p.pacchetto AS pacchetto, p.stato AS stato, p.sconto_percentuale AS sconto_percentuale,
                       v.imponibile_listino_eur AS imponibile_listino_eur, v.totale_eur AS totale_eur,
                       v.acconti_eur AS acconti_eur, p.firmata_il AS firmata_il
                  FROM arcade.pratica p
                  JOIN arcade.espositore e USING(id_espositore)
                  LEFT JOIN arcade.stand s ON s.codice=p.codice_stand
                  LEFT JOIN arcade.planimetria_stand ps ON ps.anno=p.anno AND ps.codice_stand=p.codice_stand
                  LEFT JOIN arcade.v_pratica v USING(id_pratica)
                 WHERE p.id_pratica=?
                """, practice);
        String exhibitorId = String.valueOf(facts.get("id_espositore"));
        db.execute("SET LOCAL ROLE arcade_dati_personali");
        Map<String,Object> privateData = oneOrNull("SELECT partita_iva,citta,referente,email_referente FROM arcade.espositore_riservato WHERE id_espositore=?", exhibitorId);
        db.execute("SET LOCAL ROLE arcade_api");
        if (privateData != null) facts.putAll(privateData);
        return facts;
    }

    private List<Map<String,Object>> documentLines(UUID practice) {
        List<Map<String,Object>> lines = db.queryForList("""
                SELECT v.codice_voce, l.descrizione, v.quantita, v.prezzo_unitario_eur,
                       round(v.quantita * v.prezzo_unitario_eur,2) AS importo_eur
                  FROM arcade.voce_pratica v
                  LEFT JOIN arcade.listino_voce l ON l.anno=v.anno AND l.codice_voce=v.codice_voce
                 WHERE v.id_pratica=? ORDER BY v.codice_voce
                """, practice);
        if (!lines.isEmpty()) return lines;
        return db.queryForList("""
                SELECT r.codice_voce_sorgente AS codice_voce, r.descrizione, r.quantita,
                       r.prezzo_unitario_eur, r.importo_eur
                  FROM arcade.contratto_storico_riga r
                  JOIN arcade.contratto_storico c USING(id_contratto_origine)
                 WHERE c.id_pratica=? ORDER BY r.numero_riga
                """, practice);
    }

    private List<Map<String,Object>> documentPayments(UUID practice) {
        return db.queryForList("SELECT importo_eur, ricevuto_il, riferimento FROM arcade.acconto WHERE id_pratica=? ORDER BY ricevuto_il", practice);
    }

    private UUID saveCommercialDocument(UUID practice, String type, String filename, byte[] bytes) {
        String sha256;
        try { sha256 = java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)); }
        catch (java.security.NoSuchAlgorithmException impossible) { throw new IllegalStateException("SHA-256 non disponibile", impossible); }
        db.execute("SET LOCAL ROLE arcade_api");
        return db.queryForObject("""
                INSERT INTO arcade.documento_pratica(id_pratica,tipo,nome,url,mime_type,dimensione_byte,sha256,contenuto_pdf)
                VALUES(?,?,?,NULL,'application/pdf',?,?,?) RETURNING id_documento
                """, UUID.class, practice, type, filename, bytes.length, sha256, bytes);
    }

    private List<Map<String,Object>> commercialDocumentRows(UUID practice) {
        return db.queryForList("""
                SELECT id_documento AS id,tipo,nome,url,mime_type,dimensione_byte,sha256,creato_il,
                       CASE WHEN contenuto_pdf IS NOT NULL THEN '/api/v1/pratiche/'||id_pratica||'/documenti/'||id_documento||'/download' END AS download_url
                  FROM arcade.documento_pratica WHERE id_pratica=? ORDER BY creato_il DESC
                """, practice);
    }

    private Map<String,Object> commercialDocumentRow(UUID document) {
        return one("""
                SELECT id_documento AS id,tipo,nome,url,mime_type,dimensione_byte,sha256,creato_il,
                       CASE WHEN contenuto_pdf IS NOT NULL THEN '/api/v1/pratiche/'||id_pratica||'/documenti/'||id_documento||'/download' END AS download_url
                  FROM arcade.documento_pratica WHERE id_documento=?
                """, document);
    }

    private ResponseEntity<byte[]> downloadDocument(String path) {
        String[] parts = path.split("/");
        UUID practice = uuid(parts[2]), document = uuid(parts[4]);
        Map<String,Object> row = oneOrNull("SELECT nome,mime_type,sha256,contenuto_pdf FROM arcade.documento_pratica WHERE id_documento=? AND id_pratica=?", document, practice);
        if (row == null) throw new ApiFailure(404,"DOCUMENTO_NON_TROVATO","Documento non trovato.");
        byte[] content = (byte[]) row.get("contenuto_pdf");
        if (content == null) throw new ApiFailure(404,"DOCUMENTO_NON_ARCHIVIATO","Il documento e' un collegamento esterno senza copia locale.");
        return ResponseEntity.ok()
                .header("Content-Type", String.valueOf(row.get("mime_type")))
                .header("Content-Disposition", "attachment; filename=\"" + safeFilename(String.valueOf(row.get("nome"))) + "\"")
                .header("Cache-Control", "private, no-store")
                .header("X-Content-Type-Options", "nosniff")
                .header("ETag", "\"" + row.get("sha256") + "\"")
                .body(content);
    }

    private String safeFilename(String value) {
        String cleaned = value.replaceAll("[^A-Za-z0-9._ -]", "_").replace(' ', '_');
        return cleaned.endsWith(".pdf") ? cleaned : cleaned + ".pdf";
    }

    private Object createAcconto(String p,Map<String,Object>b) {
        require(b,"importoEur","ricevutoIl"); UUID id=uuid(p.split("/")[2]);
        Map<String,Object> practice=oneOrNull("SELECT stato FROM arcade.pratica WHERE id_pratica=?",id);
        if(practice==null) throw notFound("Pratica");
        if(!List.of("FIRMATA","ACCONTO_RICEVUTO").contains(String.valueOf(practice.get("stato")))) throw new ApiFailure(409,"ACCONTO_NON_AMMESSO","Un acconto si registra solo dopo la firma della pratica.");
        BigDecimal amount=decimal(b,"importoEur");
        if(amount.signum()<=0) throw new ApiFailure(400,"IMPORTO_NON_VALIDO","L’importo deve essere maggiore di zero.");
        UUID inserted=db.queryForObject("INSERT INTO arcade.acconto(id_pratica,importo_eur,ricevuto_il,riferimento) VALUES(?,?,?,?) RETURNING id_acconto",UUID.class,id,amount,timestamp(b,"ricevutoIl"),textOrNull(b,"riferimento"));
        db.update("UPDATE arcade.pratica SET stato='ACCONTO_RICEVUTO',aggiornata_il=now() WHERE id_pratica=? AND stato='FIRMATA'",id);
        return one("SELECT id_acconto AS id,importo_eur,ricevuto_il,riferimento FROM arcade.acconto WHERE id_acconto=?",inserted);
    }

    private Object rinnovo(String p) {
        UUID previous=uuid(p.split("/")[2]);
        Map<String,Object> old=oneOrNull("SELECT * FROM arcade.pratica WHERE id_pratica=?",previous);
        if(old==null) throw notFound("Pratica");
        int nextYear=((Number)old.get("anno")).intValue()+1;
        if(old.get("codice_stand")!=null&&db.queryForObject("SELECT count(*) FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=?",Integer.class,nextYear,old.get("codice_stand"))>0) throw new ApiFailure(409,"STAND_GIA_ASSEGNATO","Lo stand originario è già occupato nella nuova edizione.");
        UUID created=db.queryForObject("INSERT INTO arcade.pratica(anno,id_espositore,codice_stand,pacchetto,sconto_percentuale,id_pratica_precedente) VALUES(?,?,?,?,?,?) RETURNING id_pratica",UUID.class,nextYear,old.get("id_espositore"),old.get("codice_stand"),old.get("pacchetto"),old.get("sconto_percentuale"),previous);
        db.update("INSERT INTO arcade.voce_pratica(id_pratica,anno,codice_voce,quantita,prezzo_unitario_eur) SELECT ?,?,codice_voce,quantita,prezzo_unitario_eur FROM arcade.voce_pratica WHERE id_pratica=?",created,nextYear,previous);
        return practice(created.toString());
    }

    private Object practice(String id) {
        return one("SELECT id_pratica AS id,anno AS edizione,id_espositore,codice_stand,stato,pacchetto,totale_eur,sconto_percentuale,approvazione_richiesta,creata_il AS created_at,aggiornata_il AS updated_at FROM arcade.v_pratica WHERE id_pratica=?",uuid(id));
    }

    private java.util.Optional<Integer> practiceEdition(UUID id) {
        return db.query("SELECT anno FROM arcade.pratica WHERE id_pratica=?",rs->rs.next()?java.util.Optional.of(rs.getInt(1)):java.util.Optional.empty(),id);
    }

    private void insertPracticeLines(UUID id,int year,Object raw,String booth) {
        if(!(raw instanceof List<?> list)||list.isEmpty()) throw new ApiFailure(400,"VOCI_LISTINO_RICHIESTE","Seleziona una voce di area espositiva per calcolare il totale.");
        Map<String,Object> layout=one("SELECT COALESCE(ps.superficie_mq,s.superficie_mq) AS superficie_mq FROM arcade.stand s LEFT JOIN arcade.planimetria_stand ps ON ps.codice_stand=s.codice AND ps.anno=? WHERE s.codice=?",year,booth);
        BigDecimal area=(BigDecimal)layout.get("superficie_mq");
        if(area==null) throw new ApiFailure(400,"SUPERFICIE_NON_DISPONIBILE","La superficie dello stand non è disponibile nel layout.");
        List<Map<String,Object>> selected=new ArrayList<>();
        for(Object value:list) {
            if(!(value instanceof Map<?,?> rawLine)) throw new ApiFailure(400,"VOCE_NON_VALIDA","Ogni voce deve specificare codiceVoce e quantita.");
            Object rawCode=rawLine.get("codiceVoce");
            if(rawCode==null) throw new ApiFailure(400,"VOCE_NON_VALIDA","Ogni voce deve specificare codiceVoce e quantita.");
            String code=String.valueOf(rawCode);
            BigDecimal quantity;
            try { quantity=new BigDecimal(String.valueOf(rawLine.get("quantita"))); }
            catch(Exception invalid) { throw new ApiFailure(400,"QUANTITA_NON_VALIDA","Quantità non valida per la voce "+code+"."); }
            if(quantity.signum()<=0) throw new ApiFailure(400,"QUANTITA_NON_VALIDA","La quantità deve essere positiva.");
            Map<String,Object> catalog=oneOrNull("SELECT codice_voce,descrizione,tipo,unita,prezzo_eur FROM arcade.listino_voce WHERE anno=? AND codice_voce=?",year,code);
            if(catalog==null) throw new ApiFailure(400,"VOCE_LISTINO_NON_TROVATA","Voce non presente nel listino dell'edizione: "+code);
            catalog.put("quantitaRichiesta",quantity);
            selected.add(catalog);
        }
        List<Map<String,Object>> areaItems=selected.stream().filter(item->String.valueOf(item.get("codice_voce")).startsWith("SPAZIO-")).toList();
        if(areaItems.size()!=1) throw new ApiFailure(400,"AREA_ESPOSITIVA_RICHIESTA","Seleziona una sola tariffa SPAZIO per l'area espositiva.");
        Map<String,Object> areaItem=areaItems.getFirst();
        BigDecimal areaRate=(BigDecimal)areaItem.get("prezzo_eur");
        db.update("INSERT INTO arcade.voce_pratica(id_pratica,anno,codice_voce,quantita,prezzo_unitario_eur) VALUES(?,?,?,?,?)",id,year,areaItem.get("codice_voce"),area,areaRate);
        for(Map<String,Object> item:selected) {
            String code=String.valueOf(item.get("codice_voce"));
            if(code.equals(areaItem.get("codice_voce"))) continue;
            String unit=String.valueOf(item.get("unita"));
            BigDecimal price=(BigDecimal)item.get("prezzo_eur");
            if("PERCENTUALE".equals(unit)) throw new ApiFailure(400,"VOCE_NON_APPLICABILE","La voce "+code+" descrive una percentuale di pagamento e non un servizio acquistabile.");
            if("PERCENTUALE_MQ".equals(unit)) {
                BigDecimal surcharge=areaRate.multiply(area).multiply(price).setScale(2,java.math.RoundingMode.HALF_UP);
                db.update("INSERT INTO arcade.voce_pratica(id_pratica,anno,codice_voce,quantita,prezzo_unitario_eur) VALUES(?,?,?,1,?)",id,year,code,surcharge);
            } else {
                BigDecimal quantity="MQ".equals(unit)?area:(BigDecimal)item.get("quantitaRichiesta");
                db.update("INSERT INTO arcade.voce_pratica(id_pratica,anno,codice_voce,quantita,prezzo_unitario_eur) VALUES(?,?,?,?,?)",id,year,code,quantity,price);
            }
        }
    }

    private void ensurePractice(UUID id) { if(db.queryForObject("SELECT count(*) FROM arcade.pratica WHERE id_pratica=?",Integer.class,id)==0) throw notFound("Pratica"); }

    private Object createAccesso(Map<String,Object>b) {
        require(b,"eventId","edizione","varco","lettoIl","codiceBiglietto");
        String code=text(b,"codiceBiglietto");
        Map<String,Object> ticket=oneOrNull("SELECT codice,id_evento,anno,giorno_valido,quantita FROM arcade.biglietto WHERE codice=?",code);
        String fingerprint=ticket==null?tokens.fingerprint(code):String.valueOf(ticket.get("id_evento"));
        Timestamp detectedAt=timestamp(b,"lettoIl");
        Map<String,Object> prior=oneOrNull("SELECT id_evento,anno,varco,letto_il,codice_biglietto,esito,motivo_rifiuto,persone FROM arcade.accesso WHERE id_evento=?",text(b,"eventId"));
        if(prior!=null) {
            if(!java.util.Objects.equals(String.valueOf(prior.get("codice_biglietto")),fingerprint)
                    && !java.util.Objects.equals(String.valueOf(prior.get("codice_biglietto")),code)
                    || ((Number)prior.get("anno")).intValue()!=number(b,"edizione")
                    || !java.util.Objects.equals(String.valueOf(prior.get("varco")),text(b,"varco"))
                    || !((Timestamp)prior.get("letto_il")).toInstant().equals(detectedAt.toInstant()))
                throw new ApiFailure(409,"EVENT_ID_RIUTILIZZATO","L’eventId è già associato a un’altra lettura.");
            return ResponseEntity.ok(map("eventId",prior.get("id_evento"),"esito",prior.get("esito"),"motivoRifiuto",prior.get("motivo_rifiuto"),"persone",prior.get("persone"),"lettoIl",prior.get("letto_il")));
        }
        String reason=null; int people=0; String result="INGRESSO_RIFIUTATO";
        if(ticket==null) reason="BIGLIETTO_NON_VALIDO";
        else if(((Number)ticket.get("anno")).intValue()!=number(b,"edizione")) reason="BIGLIETTO_NON_VALIDO";
        else if(ticket.get("giorno_valido")!=null && !LocalDate.parse(text(b,"lettoIl").substring(0,10)).equals(ticket.get("giorno_valido") instanceof Date date?date.toLocalDate():LocalDate.parse(String.valueOf(ticket.get("giorno_valido"))))) reason="GIORNO_NON_VALIDO";
        else if(db.queryForObject("SELECT count(*) FROM arcade.accesso WHERE codice_biglietto IN (?,?) AND esito='INGRESSO'",Integer.class,fingerprint,code)>0) reason="GIA_USATO";
        else { result="INGRESSO"; people=((Number)ticket.get("quantita")).intValue(); }
        db.update("INSERT INTO arcade.accesso(id_evento,anno,varco,letto_il,codice_biglietto,esito,persone,motivo_rifiuto) VALUES(?,?,?,?,?,?,?,?)",text(b,"eventId"),number(b,"edizione"),text(b,"varco"),detectedAt,fingerprint,result,people,reason);
        return map("eventId",b.get("eventId"),"esito",result,"motivoRifiuto",reason,"persone",people,"lettoIl",b.get("lettoIl"));
    }

    private Object createScansione(HttpServletRequest r,Map<String,Object>b) {
        require(b,"eventId","edizione","codiceStand","operatoreId","rilevataIl");
        String event=text(b,"eventId"), booth=text(b,"codiceStand"), rawTicket=textOrNull(b,"ticketRef");
        String ticket=rawTicket==null?null:tokens.fingerprint(rawTicket);
        boolean marketingConsent=Boolean.TRUE.equals(b.get("consensoMarketing"));
        String ageBand=textOrNull(b,"fasciaEta");
        boolean adult=ageBand!=null&&Set.of("18-24","25-34","35-44","45+").contains(ageBand);
        Long requestedLead=b.get("idLeadMagnet")==null?null:Long.valueOf(String.valueOf(b.get("idLeadMagnet")));
        if(marketingConsent&&(!Boolean.TRUE.equals(b.get("consensoEspositori"))||!adult||requestedLead==null||textOrNull(b,"email")==null))
            throw new ApiFailure(400,"LEAD_NON_IDONEO","Condividere un lead richiede email, consenso marketing, consenso all’espositore, fascia adulta e lead magnet.");
        Map<String,Object> prior=oneOrNull("SELECT id_evento,anno,codice_stand,ticket_ref,id_contatto,duplicata FROM arcade.scansione_stand WHERE id_evento=?",event);
        if(prior!=null) {
            boolean sameTicket=java.util.Objects.equals(prior.get("ticket_ref"),ticket)||java.util.Objects.equals(prior.get("ticket_ref"),rawTicket);
            if(((Number)prior.get("anno")).intValue()!=number(b,"edizione")||!java.util.Objects.equals(String.valueOf(prior.get("codice_stand")),booth)||!sameTicket) throw new ApiFailure(409,"EVENT_ID_RIUTILIZZATO","L’eventId è già associato a un’altra scansione.");
            Integer previousTotal=db.queryForObject("SELECT count(*) FROM arcade.scansione_stand WHERE anno=? AND codice_stand=? AND NOT duplicata",Integer.class,number(b,"edizione"),booth);
            boolean wasDuplicate=Boolean.TRUE.equals(prior.get("duplicata"));
            return ResponseEntity.ok(map("eventId",event,"accettata",!wasDuplicate,"duplicata",wasDuplicate,"conteggioStand",previousTotal,"leadAcquisito",prior.get("id_contatto")!=null,"messaggio","Scansione già registrata."));
        }
        if(r.getHeader("Authorization")!=null) {
            Map<String,Object> claims=tokens.authenticate(r,"DEVICE","STAFF","ESPOSITORE");
            if("ESPOSITORE".equals(claims.get("role"))&&db.queryForObject("SELECT count(*) FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=? AND id_espositore=?",Integer.class,number(b,"edizione"),booth,claims.get("idEspositore"))==0) throw new ApiFailure(403,"STAND_NON_AUTORIZZATO","L'espositore non è autorizzato a scansionare questo stand.");
        }
        boolean duplicate=ticket!=null&&db.queryForObject("SELECT count(*) FROM arcade.scansione_stand WHERE anno=? AND codice_stand=? AND ticket_ref IN (?,?) AND ticket_ref IS NOT NULL AND NOT duplicata",Integer.class,number(b,"edizione"),booth,ticket,rawTicket)>0;
        Long leadId=requestedLead;
        if(leadId!=null && db.queryForObject("SELECT count(*) FROM arcade.lead_magnet l WHERE l.id_lead_magnet=? AND l.anno=? AND l.attivo AND (l.id_espositore IS NULL OR EXISTS (SELECT 1 FROM arcade.assegnazione_stand a WHERE a.anno=l.anno AND a.id_espositore=l.id_espositore AND a.codice_stand=?))",Integer.class,leadId,number(b,"edizione"),booth)==0) throw new ApiFailure(400,"LEAD_MAGNET_NON_VALIDO","Lead magnet non attivo o non associato allo stand.");
        String contactId=null;
        if(!duplicate && marketingConsent && Boolean.TRUE.equals(b.get("consensoEspositori")) && adult && leadId!=null && textOrNull(b,"email")!=null) contactId=saveScannedContact(b,booth);
        db.update("INSERT INTO arcade.scansione_stand(id_evento,anno,codice_stand,operatore_id,rilevata_il,ticket_ref,id_contatto,id_lead_magnet,duplicata) VALUES(?,?,?,?,?,?,?,?,?)",event,number(b,"edizione"),booth,text(b,"operatoreId"),timestamp(b,"rilevataIl"),ticket,contactId,leadId,duplicate);
        Integer total=db.queryForObject("SELECT count(*) FROM arcade.scansione_stand WHERE anno=? AND codice_stand=? AND NOT duplicata",Integer.class,number(b,"edizione"),booth);
        return map("eventId",event,"accettata",!duplicate,"duplicata",duplicate,"conteggioStand",total,"leadAcquisito",contactId!=null,"messaggio",duplicate?"Scansione già registrata.":"Scansione acquisita.");
    }

    private String saveScannedContact(Map<String,Object>b,String booth) {
        Map<String,Object> assignment=oneOrNull("SELECT id_espositore FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=?",number(b,"edizione"),booth);
        if(assignment==null) throw new ApiFailure(409,"STAND_NON_ASSEGNATO","Lo stand non è associato a un espositore nell'edizione.");
        String contactId=UUID.randomUUID().toString();
        String email=text(b,"email");
        Long leadId=b.get("idLeadMagnet")==null?null:Long.valueOf(String.valueOf(b.get("idLeadMagnet")));
        String interest=leadId==null?"EVENTO":one("SELECT interesse FROM arcade.lead_magnet WHERE id_lead_magnet=?",leadId).get("interesse").toString();
        db.update("INSERT INTO arcade.contatto_stand(id_contatto,id_evento,anno,codice_stand,id_espositore,raccolto_il,fascia_eta,interesse,consenso_marketing,utilizzabile_marketing,motivo_esclusione,consenso_espositori,id_lead_magnet) VALUES(?,?,?,?,?,?,?,?, 'SI',true,'NESSUNO',true,?)",contactId,eventIdFor(contactId),number(b,"edizione"),booth,assignment.get("id_espositore"),timestamp(b,"rilevataIl"),text(b,"fasciaEta"),interest,leadId);
        db.update("INSERT INTO arcade.contatto_riservato(id_contatto,email) VALUES(?,?)",contactId,email);
        return contactId;
    }

    private String eventIdFor(String id) { return "contatto-"+id; }

    private Object createConteggio(Map<String,Object>b,String type) {
        require(b,"eventId","edizione");
        String event=text(b,"eventId");
        String requestHash=tokens.hash(json(canonicalize(b)));
        int reserved=db.update("INSERT INTO arcade.acquisizione_evento(event_id,tipo,richiesta_hash) VALUES(?,?,?) ON CONFLICT (event_id) DO NOTHING",event,type,requestHash);
        if(reserved==0) {
            Map<String,Object> prior=oneOrNull("SELECT tipo,richiesta_hash FROM arcade.acquisizione_evento WHERE event_id=?",event);
            if(prior==null) throw new ApiFailure(409,"EVENTO_GIA_RICEVUTO","L'eventId è già in uso.");
            if(!type.equals(prior.get("tipo"))||!requestHash.equals(prior.get("richiesta_hash"))) throw new ApiFailure(409,"EVENT_ID_RIUTILIZZATO","L'eventId è già associato a un'altra rilevazione.");
            return ResponseEntity.ok(map("eventId",event,"acquisita",true,"fonte",defaultText(b,"fonte","SIMULATA")));
        }
        String source=defaultText(b,"fonte","SIMULATA"); int year=number(b,"edizione");
        if(type.equals("PEDANA")) {
            require(b,"padiglione","minuto","entrati","usciti");
            db.update("INSERT INTO arcade.passaggio_pedana(anno,padiglione,minuto,entrati,usciti,fonte) VALUES(?,?,?,?,?,?)",year,text(b,"padiglione"),timestamp(b,"minuto"),number(b,"entrati"),number(b,"usciti"),source);
        } else if(type.equals("SENSORE_AI")) {
            require(b,"codiceStand","minuto","nuovePersoneFermate");
            db.update("INSERT INTO arcade.conteggio_sensore_stand(anno,codice_stand,minuto,nuove_persone_ferme,fonte) VALUES(?,?,?,?,?)",year,text(b,"codiceStand"),timestamp(b,"minuto"),number(b,"nuovePersoneFermate"),source);
        } else {
            require(b,"codiceStand","rilevatoIl","pesoLordoKg","taraKg");
            db.update("INSERT INTO arcade.rilevazione_peso(anno,codice_stand,rilevato_il,peso_lordo_kg,tara_kg,fonte) VALUES(?,?,?,?,?,?)",year,text(b,"codiceStand"),timestamp(b,"rilevatoIl"),decimal(b,"pesoLordoKg"),decimal(b,"taraKg"),source);
        }
        return map("eventId",event,"acquisita",true,"fonte",source);
    }

    private Object canonicalize(Object value) {
        if(value instanceof Map<?,?> input) {
            Map<String,Object> sorted=new java.util.TreeMap<>();
            input.forEach((key,item)->sorted.put(String.valueOf(key),canonicalize(item)));
            return sorted;
        }
        if(value instanceof List<?> input) return input.stream().map(this::canonicalize).toList();
        return value;
    }

    private Object leadMagnets(HttpServletRequest r) {
        int year=edition(r); String stand=r.getParameter("stand");
        if (r.getParameter("idEspositore") != null) throw new ApiFailure(400,"FILTRO_LEAD_MAGNET_NON_VALIDO","Usare il codice stand; gli identificativi degli espositori non sono un filtro pubblico.");
        return items(db.queryForList("SELECT id_lead_magnet AS id,anno AS edizione,codice_stand AS stand,tipo,titolo,interesse FROM arcade.v_lead_magnet_pubblici WHERE anno=? AND ((?::text IS NULL AND codice_stand IS NULL) OR (?::text IS NOT NULL AND (codice_stand IS NULL OR codice_stand=?))) ORDER BY codice_stand NULLS FIRST,titolo",year,stand,stand,stand));
    }

    private Object auditEvents(HttpServletRequest r) {
        int limit=limit(r), offset=cursor(r);
        return page(db.queryForList("SELECT event_id,occurred_at,actor_ref,actor_role,action,resource FROM arcade.audit_event ORDER BY occurred_at DESC,event_id DESC LIMIT ? OFFSET ?",limit+1,offset),limit,offset);
    }
    private Object createLeadMagnet(Map<String,Object>b) { require(b,"edizione","tipo","titolo","interesse"); Long id=db.queryForObject("INSERT INTO arcade.lead_magnet(anno,id_espositore,tipo,titolo,interesse,attivo) VALUES(?,?,?,?,?,?) RETURNING id_lead_magnet",Long.class,number(b,"edizione"),textOrNull(b,"idEspositore"),text(b,"tipo"),text(b,"titolo"),text(b,"interesse"),b.getOrDefault("attivo",true)); return one("SELECT id_lead_magnet AS id,anno AS edizione,id_espositore,tipo,titolo,interesse,attivo FROM arcade.lead_magnet WHERE id_lead_magnet=?",id); }

    private Object kpi(String p,HttpServletRequest r) {
        int year=edition(r); String filter=null,value=null;
        if(p.startsWith("/kpi/stand/")){filter="stand";value=p.substring("/kpi/stand/".length());}
        else if(p.startsWith("/kpi/espositori/")){filter="espositore";value=p.substring("/kpi/espositori/".length());}
        else if(!List.of("/kpi/direzione","/kpi/affluenza","/kpi/lead-magnet").contains(p)) throw new ApiFailure(404,"KPI_NON_TROVATO","La rotta KPI non è definita.");
        if(filter!=null) {
            Map<String,Object> claims=tokens.authenticate(r,"DIREZIONE","COMMERCIALE","ESPOSITORE","AMMINISTRATORE");
            if("ESPOSITORE".equals(claims.get("role"))) {
                if("espositore".equals(filter)&&!value.equals(claims.get("idEspositore"))) throw new ApiFailure(403,"ESPOSITORE_DIVERSO","Un espositore può leggere solo i KPI della propria organizzazione.");
                if("stand".equals(filter)&&db.queryForObject("SELECT count(*) FROM arcade.assegnazione_stand WHERE anno=? AND codice_stand=? AND id_espositore=?",Integer.class,year,value,claims.get("idEspositore"))==0) throw new ApiFailure(403,"STAND_NON_AUTORIZZATO","Un espositore può leggere i KPI solo del proprio stand.");
            }
        }
        String filterType=filter,key=value;
        String dimensionKey="stand".equals(filter)?"codiceStand":"idEspositore";
        Timestamp from=timeParameter(r.getParameter("dal"),false), to=timeParameter(r.getParameter("al"),true);
        String pavilion=r.getParameter("padiglione");
        String source=r.getParameter("fonte");
        String codeClause=switch(p) {
            case "/kpi/affluenza" -> " AND k.codice IN ('ingressi_effettivi','picco_presenza','saturazione_pct')";
            case "/kpi/lead-magnet" -> " AND k.codice IN ('mql','interesse_pubblico','resa_lead_magnet')";
            default -> "";
        };
        List<Map<String,Object>> rows=db.queryForList("""
                SELECT k.codice,k.valore,k.unita,l.anno AS edizione,k.periodo_dal,k.periodo_al,k.dimensioni,
                       l.calcolato_il,l.formula_versione,k.fonte,k.qualita,k.flag_qualita,k.stimato,k.simulato,k.nota
                FROM arcade.lotto_kpi l JOIN arcade.kpi_osservazione k USING(batch_id)
                WHERE l.batch_id=(SELECT batch_id FROM arcade.lotto_kpi WHERE anno=? ORDER BY calcolato_il DESC,ricevuto_il DESC LIMIT 1)
                  AND (?::text IS NULL OR k.dimensioni->>?=? OR k.dimensioni->>?=?)
                  AND (?::timestamptz IS NULL OR coalesce(k.periodo_al,l.calcolato_il)>=?)
                  AND (?::timestamptz IS NULL OR coalesce(k.periodo_dal,l.calcolato_il)<=?)
                  AND (?::text IS NULL OR k.dimensioni->>'padiglione'=? )
                  AND (?::text IS NULL OR ? = ANY(k.fonte))
                """+codeClause+" ORDER BY k.codice,k.periodo_dal NULLS FIRST",year,filterType,dimensionKey,key,dimensionKey.equals("codiceStand")?"codice_stand":dimensionKey,key,from,from,to,to,pavilion,pavilion,source,source);
        return map("edizione",year,"items",rows);
    }

    private Object avvisi(HttpServletRequest r) { return items(db.queryForList("SELECT id_avviso AS id,titolo,testo,pubblico,pubblicato_il,attivo FROM arcade.avviso WHERE attivo AND (?::text IS NULL OR pubblico=?) ORDER BY pubblicato_il DESC",r.getParameter("pubblico"),r.getParameter("pubblico"))); }
    private Object createAvviso(Map<String,Object>b) { require(b,"titolo","testo","pubblico"); UUID id=db.queryForObject("INSERT INTO arcade.avviso(titolo,testo,pubblico,pubblicato_il,attivo) VALUES(?,?,?,coalesce(?::timestamptz,now()),coalesce(?::boolean,true)) RETURNING id_avviso",UUID.class,text(b,"titolo"),text(b,"testo"),text(b,"pubblico"),textOrNull(b,"pubblicatoIl"),b.get("attivo")); return one("SELECT id_avviso AS id,titolo,testo,pubblico,pubblicato_il,attivo FROM arcade.avviso WHERE id_avviso=?",id); }
    private Object updateAvviso(String p,Map<String,Object>b) { UUID id=uuid(p.substring("/avvisi/".length())); int n=db.update("UPDATE arcade.avviso SET titolo=coalesce(?,titolo),testo=coalesce(?,testo),pubblico=coalesce(?,pubblico),pubblicato_il=coalesce(?::timestamptz,pubblicato_il),attivo=coalesce(?::boolean,attivo) WHERE id_avviso=?",b.get("titolo"),b.get("testo"),b.get("pubblico"),b.get("pubblicatoIl"),b.get("attivo"),id); if(n==0) throw notFound("Avviso"); return one("SELECT id_avviso AS id,titolo,testo,pubblico,pubblicato_il,attivo FROM arcade.avviso WHERE id_avviso=?",id); }

    private Object putEdizione(String p,Map<String,Object>b) { int year=Integer.parseInt(p.substring("/admin/edizioni/".length())); require(b,"stato"); int n=db.update("INSERT INTO arcade.edizione(anno,sede,inizio_vendite,inizio_fiera,fine_fiera,stato) VALUES(?,?,?,?,?,?) ON CONFLICT(anno) DO UPDATE SET sede=excluded.sede,inizio_vendite=excluded.inizio_vendite,inizio_fiera=excluded.inizio_fiera,fine_fiera=excluded.fine_fiera,stato=excluded.stato",year,textOrNull(b,"sede"),textOrNull(b,"inizioVendite"),textOrNull(b,"inizioFiera"),textOrNull(b,"fineFiera"),text(b,"stato")); return one("SELECT anno,sede,inizio_vendite,inizio_fiera,fine_fiera,stato FROM arcade.edizione WHERE anno=?",year); }
    private Object updateParametri(String p,Map<String,Object>b) {
        int year=Integer.parseInt(p.split("/")[3]);
        // Insert only the key first so PostgreSQL applies defaults before a partial PATCH.
        db.update("INSERT INTO arcade.parametri_stima(anno) VALUES(?) ON CONFLICT(anno) DO NOTHING",year);
        db.update("""
                UPDATE arcade.parametri_stima
                   SET ore_permanenza=coalesce(?,ore_permanenza),
                       peso_medio_kg=coalesce(?,peso_medio_kg),
                       soglia_rumore_kg=coalesce(?,soglia_rumore_kg),
                       persone_per_mq=coalesce(?,persone_per_mq)
                 WHERE anno=?
                """,decimalOrNull(b,"orePermanenza"),decimalOrNull(b,"pesoMedioKg"),
                decimalOrNull(b,"sogliaRumoreKg"),decimalOrNull(b,"personePerMq"),year);
        return one("SELECT anno AS edizione,ore_permanenza,peso_medio_kg,soglia_rumore_kg,persone_per_mq FROM arcade.parametri_stima WHERE anno=?",year);
    }

    private Object exportBi(String p,HttpServletRequest r) {
        int year=edition(r),limit=limit(r),offset=cursor(r); String source=p.substring("/bi/dati/".length());
        String query=switch(source) {
            case "vendite" -> "SELECT * FROM arcade.v_bi_vendite WHERE edizione=? ORDER BY registrato_il LIMIT ? OFFSET ?";
            case "accessi" -> "SELECT * FROM arcade.v_bi_accessi WHERE edizione=? ORDER BY letto_il LIMIT ? OFFSET ?";
            case "stand" -> "SELECT * FROM arcade.v_bi_stand WHERE edizione=? ORDER BY intervallo_dal LIMIT ? OFFSET ?";
            case "commerciale" -> "SELECT * FROM arcade.v_bi_commerciale WHERE edizione=? ORDER BY espositore_ref LIMIT ? OFFSET ?";
            case "qualita" -> "SELECT anno AS edizione,tabella AS fonte,flag AS codice,righe AS conteggio FROM arcade.v_registro_anomalie WHERE anno=? ORDER BY tabella,flag LIMIT ? OFFSET ?";
            default -> throw new ApiFailure(404,"ROUTE_BI_NON_TROVATA","Flusso BI non definito.");
        };
        List<Map<String,Object>> rows=db.queryForList(query,year,limit+1,offset);
        if(source.equals("vendite")) for(Map<String,Object> row:rows) {
            String edition=String.valueOf(row.get("edizione"));
            row.put("ticket_ref",tokens.fingerprint(edition+"|"+row.get("ticket_ref")));
            row.put("ordine_ref",tokens.fingerprint(edition+"|ordine|"+row.get("ordine_ref")));
        }
        if(source.equals("accessi")) for(Map<String,Object> row:rows) {
            Object matched=row.remove("matched_ticket_ref");
            String raw=String.valueOf(row.remove("raw_ticket_ref"));
            String edition=String.valueOf(row.get("edizione"));
            row.put("ticket_ref",tokens.fingerprint(edition+"|"+(matched==null?raw:matched)));
        }
        return map("edizione",year,"items",rows,"page",map("limit",limit,"nextCursor",rows.size()>limit?String.valueOf(offset+limit):null),"estrattoIl",Instant.now().toString());
    }

    private Object receiveKpi(String p,Map<String,Object>b) {
        require(b,"edizione","calcolatoIl","formulaVersione","items"); UUID batch=uuid(p.substring("/integrazioni/bad/kpi/".length()));
        if(db.queryForObject("SELECT count(*) FROM arcade.lotto_kpi WHERE batch_id=?",Integer.class,batch)>0) return map("batchId",batch,"stato","GIA_RICEVUTO","ricevutoIl",Instant.now().toString(),"elementiAccettati",0,"elementiRifiutati",0);
        Object raw=b.get("items");
        if(!(raw instanceof List<?> list)||list.isEmpty()) throw new ApiFailure(400,"KPI_VUOTI","Il lotto deve contenere almeno un’osservazione.");
        int year=number(b,"edizione"); Timestamp calculatedAt=timestamp(b,"calcolatoIl"); String formula=text(b,"formulaVersione");
        Set<String> codes=Set.of("visitatori_venduti","ingressi_effettivi","picco_presenza","saturazione_pct","visitatori_per_mq","ricavo_per_mq","costo_per_contatto","visite_stand","contatti_stand","contatti_per_100_visite","contatti_su_persone_ferme_pct","mql","interesse_pubblico","resa_lead_magnet");
        for(Object object:list) {
            if(!(object instanceof Map<?,?> rawItem)) throw new ApiFailure(400,"KPI_NON_VALIDO","Ogni osservazione deve essere un oggetto KPI.");
            @SuppressWarnings("unchecked") Map<String,Object> item=(Map<String,Object>)rawItem;
            require(item,"codice","valore","unita","edizione","calcolatoIl","formulaVersione","fonte","qualita","stimato","simulato");
            if(!codes.contains(text(item,"codice"))) throw new ApiFailure(400,"CODICE_KPI_NON_VALIDO","Codice KPI non previsto dal contratto.");
            if(number(item,"edizione")!=year||!timestamp(item,"calcolatoIl").toInstant().equals(calculatedAt.toInstant())||!formula.equals(text(item,"formulaVersione"))) throw new ApiFailure(400,"METADATI_KPI_NON_COHERENTI","Edizione, istante e versione formula devono coincidere con il lotto.");
            if(!(item.get("valore") instanceof Number)||!(item.get("unita") instanceof String)||!(item.get("dimensioni")==null||item.get("dimensioni") instanceof Map<?,?>)||!(item.get("stimato") instanceof Boolean)||!(item.get("simulato") instanceof Boolean)) throw new ApiFailure(400,"KPI_NON_VALIDO","Tipi non validi nell’osservazione KPI.");
            if(!List.of("OK","ATTENZIONE","DA_VERIFICARE").contains(text(item,"qualita"))) throw new ApiFailure(400,"QUALITA_KPI_NON_VALIDA","Valore qualita non previsto dal contratto.");
            postgresTextArray(item.get("fonte"),"fonte",true);
            postgresTextArray(item.get("flagQualita"),"flagQualita",false);
        }
        int inserted=db.update("INSERT INTO arcade.lotto_kpi(batch_id,anno,calcolato_il,formula_versione,intervallo_dati_dal,intervallo_dati_al) VALUES(?,?,?,?,?,?) ON CONFLICT(batch_id) DO NOTHING",batch,year,calculatedAt,text(b,"formulaVersione"),timestampOrNull(b,"intervalloDatiDal"),timestampOrNull(b,"intervalloDatiAl"));
        if(inserted==0) return map("batchId",batch,"stato","GIA_RICEVUTO","ricevutoIl",Instant.now().toString(),"elementiAccettati",0,"elementiRifiutati",0);
        int accepted=0;
        for(Object object:list) {
            @SuppressWarnings("unchecked") Map<String,Object> item=(Map<String,Object>)object;
            db.update("INSERT INTO arcade.kpi_osservazione(batch_id,codice,valore,unita,periodo_dal,periodo_al,dimensioni,fonte,qualita,flag_qualita,stimato,simulato,nota) VALUES(?,?,?,?,?,?,?::jsonb,?::text[],?,?::text[],?::boolean,?::boolean,?)",
                    batch,item.get("codice"),new BigDecimal(String.valueOf(item.get("valore"))),item.get("unita"),timestampValue(item.get("periodoDal"),"periodoDal"),timestampValue(item.get("periodoAl"),"periodoAl"),json(item.get("dimensioni")),postgresTextArray(item.get("fonte"),"fonte",true),item.get("qualita"),postgresTextArray(item.get("flagQualita"),"flagQualita",false),item.get("stimato"),item.get("simulato"),item.get("nota")); accepted++;
        }
        return map("batchId",batch,"stato","ACCETTATO","ricevutoIl",Instant.now().toString(),"elementiAccettati",accepted,"elementiRifiutati",0);
    }

    private Object presenzePeso(HttpServletRequest r,int year,String unused) { return presenzePeso(r,year); }

    private int activeEdition() { List<Integer> years=db.query("SELECT anno FROM arcade.edizione WHERE stato='ATTIVA' ORDER BY anno DESC LIMIT 1",(rs,n)->rs.getInt(1)); return years.isEmpty()?2026:years.get(0); }
    private int edition(HttpServletRequest r) { String value=r.getParameter("edizione"); if(value==null) value=r.getParameter("anno"); return value==null?activeEdition():Integer.parseInt(value); }
    private int limit(HttpServletRequest r) { return Math.max(1,Math.min(200,Integer.parseInt(r.getParameter("limit")==null?"50":r.getParameter("limit")))); }
    private int cursor(HttpServletRequest r) { String c=r.getParameter("cursor"); if(c==null||c.isBlank()) return 0; try{return Math.max(0,Integer.parseInt(c));}catch(NumberFormatException e){throw new ApiFailure(400,"CURSORE_NON_VALIDO","Il cursore deve identificare un offset numerico.");} }
    private Boolean bool(HttpServletRequest r,String name) { String value=r.getParameter(name); return value==null?null:Boolean.valueOf(value); }
    private Object page(List<Map<String,Object>> rows,int limit,int offset) { boolean next=rows.size()>limit; List<Map<String,Object>> shown=next?rows.subList(0,limit):rows; return map("items",shown,"page",map("limit",limit,"nextCursor",next?String.valueOf(offset+limit):null)); }
    private Object items(List<Map<String,Object>> items) { return map("items",items); }
    @SuppressWarnings("unchecked") private List<Map<String,Object>> castItems(Object value) { return (List<Map<String,Object>>)((Map<String,Object>)value).get("items"); }
    private Map<String,Object> one(String sql,Object... args) { Map<String,Object> result=oneOrNull(sql,args); if(result==null) throw notFound("Risorsa"); return result; }
    private Map<String,Object> oneOrNull(String sql,Object... args) { List<Map<String,Object>> rows=db.queryForList(sql,args); return rows.isEmpty()?null:rows.get(0); }
    private ApiFailure notFound(String type) { return new ApiFailure(404,"RISORSA_NON_TROVATA",type+" non trovata."); }
    private Map<String,Object> map(Object... values) { Map<String,Object> result=new LinkedHashMap<>(); for(int i=0;i<values.length;i+=2) result.put(String.valueOf(values[i]),values[i+1]); return result; }
    private void require(Map<String,Object>b,String... names) { for(String name:names) if(!b.containsKey(name)||b.get(name)==null||String.valueOf(b.get(name)).isBlank()) throw new ApiFailure(400,"CAMPO_OBBLIGATORIO","Campo obbligatorio mancante: "+name); }
    private String text(Map<String,Object>b,String key) { return String.valueOf(b.get(key)); }
    private String textOrNull(Map<String,Object>b,String key) { Object v=b.get(key); return v==null||String.valueOf(v).isBlank()?null:String.valueOf(v); }
    private String defaultText(Map<String,Object>b,String key,String fallback) { return textOrNull(b,key)==null?fallback:text(b,key); }
    private boolean boolValue(Map<String,Object>b,String key) { return Boolean.parseBoolean(String.valueOf(b.getOrDefault(key,false))); }
    private int number(Map<String,Object>b,String key) { try{return Integer.parseInt(String.valueOf(b.get(key)));}catch(Exception e){throw new ApiFailure(400,"NUMERO_NON_VALIDO","Campo numerico non valido: "+key);} }
    private BigDecimal decimal(Map<String,Object>b,String key) { try{return new BigDecimal(String.valueOf(b.get(key)));}catch(Exception e){throw new ApiFailure(400,"NUMERO_NON_VALIDO","Campo numerico non valido: "+key);} }
    private BigDecimal decimalOr(Map<String,Object>b,String key,BigDecimal fallback) { return b.get(key)==null?fallback:decimal(b,key); }
    private BigDecimal decimalOrNull(Map<String,Object>b,String key) { return b.get(key)==null?null:decimal(b,key); }
    private UUID uuid(String value) { try{return UUID.fromString(value);}catch(Exception e){throw new ApiFailure(400,"ID_NON_VALIDO","Identificativo non valido.");} }
    private Timestamp timestamp(Map<String,Object>b,String key) { try{return Timestamp.from(OffsetDateTime.parse(text(b,key)).toInstant());}catch(Exception e){try{return Timestamp.valueOf(java.time.LocalDateTime.parse(text(b,key)));}catch(Exception ignored){throw new ApiFailure(400,"DATA_NON_VALIDA","Data non valida: "+key);}} }
    private Timestamp timestampOrNull(Map<String,Object>b,String key) { return b.get(key)==null?null:timestamp(b,key); }
    private Timestamp timestampValue(Object value,String key) { return value==null?null:timestamp(Map.of(key,value),key); }
    private String postgresTextArray(Object value,String key,boolean required) {
        if(value==null&&!required) return "{}";
        if(!(value instanceof List<?> values)||required&&values.isEmpty()) throw new ApiFailure(400,"ARRAY_NON_VALIDO","Campo array non valido: "+key);
        List<String> escaped=new ArrayList<>();
        for(Object item:values) {
            if(!(item instanceof String text)||text.indexOf('\0')>=0) throw new ApiFailure(400,"ARRAY_NON_VALIDO","Campo array non valido: "+key);
            escaped.add("\""+text.replace("\\","\\\\").replace("\"","\\\"")+"\"");
        }
        return "{"+String.join(",",escaped)+"}";
    }
    private Timestamp timeParameter(String value,boolean endOfDay) {
        if(value==null||value.isBlank()) return null;
        try { return Timestamp.from(OffsetDateTime.parse(value).toInstant()); }
        catch(Exception ignored) {
            try {
                LocalDate day=LocalDate.parse(value);
                java.time.LocalDateTime local=endOfDay?day.plusDays(1).atStartOfDay().minusNanos(1):day.atStartOfDay();
                return Timestamp.from(local.atZone(java.time.ZoneId.of("Europe/Rome")).toInstant());
            } catch(Exception invalid) { throw new ApiFailure(400,"DATA_NON_VALIDA","Filtro data non valido."); }
        }
    }
    private String randomToken() { byte[] bytes=new byte[32];random.nextBytes(bytes);return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); }
    private Map<String,Object> tokenResponse(String token) { return map("accessToken",token,"tokenType","Bearer","expiresIn",3600); }

    private String hashPassword(String password) {
        if(password.length()<12) throw new ApiFailure(400,"PASSWORD_DEBOLE","La password deve contenere almeno 12 caratteri.");
        try { byte[] salt=new byte[16];random.nextBytes(salt);javax.crypto.SecretKeyFactory factory=javax.crypto.SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");javax.crypto.spec.PBEKeySpec spec=new javax.crypto.spec.PBEKeySpec(password.toCharArray(),salt,210000,256);byte[] hash=factory.generateSecret(spec).getEncoded();return "pbkdf2$210000$"+Base64.getEncoder().encodeToString(salt)+"$"+Base64.getEncoder().encodeToString(hash); } catch(Exception e){throw new IllegalStateException(e);}
    }
    private boolean verifyPassword(String password,String stored) {
        try { String[] p=stored.split("\\$"); if(p.length!=4||!p[0].equals("pbkdf2")) return false; byte[] salt=Base64.getDecoder().decode(p[2]);byte[] expected=Base64.getDecoder().decode(p[3]);javax.crypto.SecretKeyFactory factory=javax.crypto.SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");byte[] actual=factory.generateSecret(new javax.crypto.spec.PBEKeySpec(password.toCharArray(),salt,Integer.parseInt(p[1]),expected.length*8)).getEncoded();return java.security.MessageDigest.isEqual(expected,actual);}catch(Exception e){return false;}
    }
    private String json(Object value) { try{return new tools.jackson.databind.ObjectMapper().writeValueAsString(value==null?Map.of():value);}catch(Exception e){throw new IllegalArgumentException("JSON non valido");} }
    private Object camelize(Object value) {
        if (value instanceof PGobject pg) {
            try { return new tools.jackson.databind.ObjectMapper().readValue(pg.getValue(), Object.class); }
            catch (Exception ignored) { return pg.getValue(); }
        }
        // PostgreSQL arrays are JDBC wrappers; serializing them directly can expose driver internals
        // and create malformed/circular JSON. Convert the values to an ordinary JSON list first.
        if (value instanceof java.sql.Array sqlArray) {
            try {
                Object raw = sqlArray.getArray();
                if (raw == null || !raw.getClass().isArray()) return raw;
                List<Object> result = new ArrayList<>();
                for (int i = 0; i < java.lang.reflect.Array.getLength(raw); i++) {
                    result.add(camelize(java.lang.reflect.Array.get(raw, i)));
                }
                return result;
            } catch (java.sql.SQLException exception) {
                throw new IllegalStateException("Impossibile leggere un array PostgreSQL", exception);
            } finally {
                try { sqlArray.free(); } catch (java.sql.SQLException ignored) { }
            }
        }
        if (value instanceof Map<?, ?> input) {
            Map<String,Object> output=new LinkedHashMap<>();
            input.forEach((key,item)->output.put(camel(String.valueOf(key)),camelize(item)));
            return output;
        }
        if (value instanceof List<?> input) return input.stream().map(this::camelize).toList();
        return value;
    }
    private String camel(String value) {
        StringBuilder result=new StringBuilder(); boolean upper=false;
        for(char c:value.toCharArray()) { if(c=='_') upper=true; else { result.append(upper?Character.toUpperCase(c):c); upper=false; } }
        return result.toString();
    }
    private void assertPracticeOwner(String id,Map<String,Object> claims) {
        UUID practice=uuid(id);
        if(db.queryForObject("SELECT count(*) FROM arcade.pratica WHERE id_pratica=? AND id_espositore=?",Integer.class,practice,claims.get("idEspositore"))==0) throw new ApiFailure(404,"PRATICA_NON_TROVATA","Pratica non trovata.");
    }

    /** Autenticazione Google OAuth */
    @Transactional
    private Object googleAuth(Map<String, Object> b) {
        require(b, "token", "email", "subject");
        String token = text(b, "token");
        String email = text(b, "email");
        String subject = text(b, "subject");

        Map<String, Object> existing = oneOrNull(
            "SELECT a.id_account FROM arcade.account_espositore a "
            + "JOIN arcade.identita_esterna ie ON ie.id_account = a.id_account "
            + "WHERE ie.fornitore = 'GOOGLE' AND ie.subject = ?", subject
        );

        UUID accountId;
        if (existing != null) {
            accountId = uuid(String.valueOf(existing.get("id_account")));
            db.update("UPDATE arcade.account_espositore SET ultimo_accesso = now() WHERE id_account = ?", accountId);
            db.update("UPDATE arcade.identita_esterna SET ultimo_accesso = now(), email = ? WHERE id_account = ? AND fornitore = 'GOOGLE' AND subject = ?", email, accountId, subject);
        } else {
            Map<String, Object> accountByEmail = oneOrNull("SELECT id_account FROM arcade.account_espositore WHERE email = ?", email);
            if (accountByEmail == null) throw new ApiFailure(404, "ACCOUNT_NON_TROVATO", "Nessun account per email: " + email);
            accountId = uuid(String.valueOf(accountByEmail.get("id_account")));
            db.update("INSERT INTO arcade.identita_esterna (id_account, fornitore, subject, email, email_verificata, primo_accesso, ultimo_accesso) VALUES (?, 'GOOGLE', ?, ?, true, now(), now()) ON CONFLICT (fornitore, subject) DO NOTHING", accountId, subject, email, email);
            db.update("UPDATE arcade.account_espositore SET ultimo_accesso = now(), email_verificata = true WHERE id_account = ?", accountId);
        }
        db.update("UPDATE arcade.account_espositore SET email_fornitore = ? WHERE id_account = ?", email, accountId);

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("sub", accountId.toString());
        claims.put("email", email);
        claims.put("role", "ESPOSITORE");
        String exhibitorId = db.queryForObject("SELECT id_espositore FROM arcade.account_espositore WHERE id_account = ?", String.class, accountId);
        if (exhibitorId != null) claims.put("idEspositore", exhibitorId);
        return map("accessToken", tokens.issue(accountId.toString(), "ESPOSITORE", exhibitorId, 3600L), "tokenType", "Bearer");
    }

    /** Autenticazione Microsoft OAuth */
    @Transactional
    private Object microsoftAuth(Map<String, Object> b) {
        require(b, "token", "email", "subject");
        String token = text(b, "token");
        String email = text(b, "email");
        String subject = text(b, "subject");

        Map<String, Object> existing = oneOrNull(
            "SELECT a.id_account FROM arcade.account_espositore a "
            + "JOIN arcade.identita_esterna ie ON ie.id_account = a.id_account "
            + "WHERE ie.fornitore = 'MICROSOFT' AND ie.subject = ?", subject
        );

        UUID accountId;
        if (existing != null) {
            accountId = uuid(String.valueOf(existing.get("id_account")));
            db.update("UPDATE arcade.account_espositore SET ultimo_accesso = now() WHERE id_account = ?", accountId);
            db.update("UPDATE arcade.identita_esterna SET ultimo_accesso = now(), email = ? WHERE id_account = ? AND fornitore = 'MICROSOFT' AND subject = ?", email, accountId, subject);
        } else {
            Map<String, Object> accountByEmail = oneOrNull("SELECT id_account FROM arcade.account_espositore WHERE email = ?", email);
            if (accountByEmail == null) throw new ApiFailure(404, "ACCOUNT_NON_TROVATO", "Nessun account per email: " + email);
            accountId = uuid(String.valueOf(accountByEmail.get("id_account")));
            db.update("INSERT INTO arcade.identita_esterna (id_account, fornitore, subject, email, email_verificata, primo_accesso, ultimo_accesso) VALUES (?, 'MICROSOFT', ?, ?, true, now(), now()) ON CONFLICT (fornitore, subject) DO NOTHING", accountId, subject, email, email);
            db.update("UPDATE arcade.account_espositore SET ultimo_accesso = now(), email_verificata = true WHERE id_account = ?", accountId);
        }
        db.update("UPDATE arcade.account_espositore SET email_fornitore = ? WHERE id_account = ?", email, accountId);

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("sub", accountId.toString());
        claims.put("email", email);
        claims.put("role", "ESPOSITORE");
        String exhibitorId = db.queryForObject("SELECT id_espositore FROM arcade.account_espositore WHERE id_account = ?", String.class, accountId);
        if (exhibitorId != null) claims.put("idEspositore", exhibitorId);
        return map("accessToken", tokens.issue(accountId.toString(), "ESPOSITORE", exhibitorId, 3600L), "tokenType", "Bearer");
    }

}
