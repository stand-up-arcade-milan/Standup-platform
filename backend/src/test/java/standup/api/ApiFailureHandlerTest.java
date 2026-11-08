package standup.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

class ApiFailureHandlerTest {
    @Test
    void apiFailuresUseTheSharedErrorResponseShape() {
        HttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/espositori/me");
        ResponseEntity<Map<String, Object>> response = new ApiFailureHandler().handle(
                new ApiFailure(403, "RUOLO_NON_AUTORIZZATO", "Accesso negato"), request);

        assertEquals(403, response.getStatusCode().value());
        Object responseBody = response.getBody();
        assertTrue(responseBody instanceof Map<?, ?>);
        Map<?, ?> body = (Map<?, ?>) responseBody;
        assertEquals(403, body.get("status"));
        assertEquals("RUOLO_NON_AUTORIZZATO", body.get("code"));
        assertEquals("Accesso negato", body.get("detail"));
        assertEquals("/api/v1/espositori/me", body.get("instance"));
        assertNotNull(body.get("requestId"));
        assertNotNull(body.get("timestamp"));
    }
}
