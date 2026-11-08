package standup.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.mock.web.MockHttpServletRequest;
import tools.jackson.databind.ObjectMapper;

class ApiTokensTest {
    private static final String SECRET = "unit-test-secret-that-is-at-least-32-bytes";
    private final ApiTokens tokens = new ApiTokens(new ObjectMapper(), SECRET);

    @Test
    void issuedTokenAuthenticatesForItsRole() {
        HttpServletRequest request = requestWithToken(tokens.issue("bad-service", "BAD", null, 60));

        var claims = tokens.authenticate(request, "BAD");

        assertEquals("bad-service", claims.get("sub"));
        assertEquals("BAD", claims.get("role"));
    }

    @Test
    void missingTokenIsUnauthorized() {
        ApiFailure failure = assertThrows(ApiFailure.class,
                () -> tokens.authenticate(new MockHttpServletRequest(), "BAD"));

        assertEquals(401, failure.status());
        assertEquals("TOKEN_MANCANTE", failure.code());
    }

    @Test
    void expiredOrTamperedTokenIsUnauthorized() {
        String expired = tokens.issue("bad-service", "BAD", null, -1);
        String valid = tokens.issue("bad-service", "BAD", null, 60);
        String[] segments = valid.split("\\.");
        String tampered = segments[0] + "." + segments[1] + ".AA";

        for (String token : new String[] { expired, tampered }) {
            ApiFailure failure = assertThrows(ApiFailure.class,
                    () -> tokens.authenticate(requestWithToken(token), "BAD"));
            assertEquals(401, failure.status());
            assertEquals("TOKEN_NON_VALIDO", failure.code());
        }
    }

    @Test
    void validTokenWithWrongRoleIsForbidden() {
        HttpServletRequest request = requestWithToken(tokens.issue("staff-user", "STAFF", null, 60));

        ApiFailure failure = assertThrows(ApiFailure.class,
                () -> tokens.authenticate(request, "BAD"));

        assertEquals(403, failure.status());
        assertEquals("RUOLO_NON_AUTORIZZATO", failure.code());
    }

    @Test
    void fingerprintIsStableAndDoesNotExposeTheInput() {
        String reference = "ticket-reference-that-must-stay-private";

        String first = tokens.fingerprint(reference);

        assertEquals(first, tokens.fingerprint(reference));
        assertEquals(64, first.length());
        assertFalse(first.contains(reference));
    }

    @Test
    void productionModeRejectsLocalInternalTokensButAllowsExhibitorAccountTokens() {
        OidcTokens unavailable = new OidcTokens(token -> { throw new JwtException("No enterprise identity provider configured in this test."); }, "roles", "idEspositore");
        ApiTokens production = new ApiTokens(new ObjectMapper(), unavailable, SECRET, false);
        String badToken = tokens.issue("bad-service", "BAD", null, 60);
        String exhibitorToken = tokens.issue("exhibitor@example.test", "ESPOSITORE", "ESP-1", 60);

        assertEquals(401, assertThrows(ApiFailure.class,
                () -> production.authenticate(requestWithToken(badToken), "BAD")).status());
        assertEquals("ESP-1", production.authenticate(requestWithToken(exhibitorToken), "ESPOSITORE").get("idEspositore"));
    }

    private MockHttpServletRequest requestWithToken(String token) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", "Bearer " + token);
        return request;
    }
}
