package standup.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.sql.Array;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.http.ResponseEntity;
import tools.jackson.databind.ObjectMapper;

class PlatformApiControllerTest {
    private static final String SECRET = "unit-test-secret-that-is-at-least-32-bytes";

    private final JdbcTemplate db = mock(JdbcTemplate.class);
    private final ApiTokens tokens = new ApiTokens(new ObjectMapper(), SECRET);
    private final PlatformApiController controller = new PlatformApiController(db, tokens);

    @Test
    void healthIsPublicAndDoesNotQueryTheDatabase() {
        ResponseEntity<?> response = controller.dispatch(request("GET", "/api/v1/health"), null);

        assertEquals(200, response.getStatusCode().value());
        assertEquals(Map.of("service", "standup-platform-api", "status", "UP"), response.getBody());
        verify(db, times(0)).queryForList(anyString(), any(Object[].class));
    }

    @Test
    void bidExportRejectsAValidTokenWithAnUnapprovedRole() {
        MockHttpServletRequest request = request("GET", "/api/v1/bi/dati/vendite");
        request.addHeader("Authorization", "Bearer " + tokens.issue("staff-user", "STAFF", null, 60));

        ApiFailure failure = assertThrows(ApiFailure.class,
                () -> controller.dispatch(request, null));

        assertEquals(403, failure.status());
        assertEquals("RUOLO_NON_AUTORIZZATO", failure.code());
    }

    @Test
    void salesExportPseudonymizesReferencesAndConvertsPostgresArrays() throws Exception {
        Array qualityFlags = mock(Array.class);
        when(qualityFlags.getArray()).thenReturn(new String[] { "FLAG_STORICO" });
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("ticket_ref", "raw-ticket-ref");
        row.put("ordine_ref", "raw-order-ref");
        row.put("edizione", 2025);
        row.put("categoria", "INTERO");
        row.put("canale", "ONLINE");
        row.put("giorno_valido", null);
        row.put("quantita", 1);
        row.put("importo_eur", new BigDecimal("42.00"));
        row.put("registrato_il", Timestamp.from(Instant.parse("2025-04-01T10:00:00Z")));
        row.put("flag_qualita", qualityFlags);
        when(db.queryForList(anyString(), any(Object[].class))).thenReturn(List.of(row));
        MockHttpServletRequest request = request("GET", "/api/v1/bi/dati/vendite");
        request.addParameter("edizione", "2025");
        request.addParameter("limit", "10");
        request.addHeader("Authorization", "Bearer " + tokens.issue("bad-service", "BAD", null, 60));

        ResponseEntity<?> response = controller.dispatch(request, null);

        assertEquals(200, response.getStatusCode().value());
        Map<?, ?> body = assertInstanceOf(Map.class, response.getBody());
        List<?> items = assertInstanceOf(List.class, body.get("items"));
        Map<?, ?> item = assertInstanceOf(Map.class, items.getFirst());
        String ticketRef = assertInstanceOf(String.class, item.get("ticketRef"));
        String orderRef = assertInstanceOf(String.class, item.get("ordineRef"));
        assertEquals(64, ticketRef.length());
        assertEquals(64, orderRef.length());
        assertFalse(ticketRef.contains("raw-ticket-ref"));
        assertFalse(orderRef.contains("raw-order-ref"));
        assertEquals(List.of("FLAG_STORICO"), item.get("flagQualita"));
        assertNotNull(body.get("page"));
        verify(qualityFlags).free();
    }

    @Test
    void kpiBatchIsAcceptedOnceAndUsesPostgresArrayCasts() {
        UUID batchId = UUID.randomUUID();
        String calculatedAt = "2026-11-08T10:15:30Z";
        Map<String, Object> observation = new LinkedHashMap<>();
        observation.put("codice", "visite_stand");
        observation.put("valore", 12);
        observation.put("unita", "visite");
        observation.put("edizione", 2026);
        observation.put("calcolatoIl", calculatedAt);
        observation.put("formulaVersione", "test-1");
        observation.put("fonte", List.of("UNIT_TEST"));
        observation.put("qualita", "DA_VERIFICARE");
        observation.put("stimato", false);
        observation.put("simulato", true);
        observation.put("flagQualita", List.of("TEST"));
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("edizione", 2026);
        payload.put("calcolatoIl", calculatedAt);
        payload.put("formulaVersione", "test-1");
        payload.put("items", List.of(observation));
        when(db.queryForObject(anyString(), eq(Integer.class), any(Object[].class))).thenReturn(0, 1);
        when(db.update(anyString(), any(Object[].class))).thenReturn(1, 1);
        MockHttpServletRequest firstRequest = request("PUT", "/api/v1/integrazioni/bad/kpi/" + batchId);
        firstRequest.addHeader("Authorization", "Bearer " + tokens.issue("bad-service", "BAD", null, 60));
        MockHttpServletRequest retryRequest = request("PUT", "/api/v1/integrazioni/bad/kpi/" + batchId);
        retryRequest.addHeader("Authorization", firstRequest.getHeader("Authorization"));

        ResponseEntity<?> first = controller.dispatch(firstRequest, payload);
        ResponseEntity<?> retry = controller.dispatch(retryRequest, payload);

        assertEquals(201, first.getStatusCode().value());
        assertEquals(200, retry.getStatusCode().value());
        Map<?, ?> firstBody = assertInstanceOf(Map.class, first.getBody());
        Map<?, ?> retryBody = assertInstanceOf(Map.class, retry.getBody());
        assertEquals("ACCETTATO", firstBody.get("stato"));
        assertEquals("GIA_RICEVUTO", retryBody.get("stato"));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(db, times(2)).update(sql.capture(), any(Object[].class));
        assertTrue(sql.getAllValues().get(1).contains("flag_qualita"));
        assertTrue(sql.getAllValues().get(1).contains("?::text[]"));
    }

    private MockHttpServletRequest request(String method, String uri) {
        return new MockHttpServletRequest(method, uri);
    }
}
