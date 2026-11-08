package standup.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtException;

class OidcTokensTest {
    @Test
    void mapsOneRecognizedOidcRoleAndExhibitorIdentifier() {
        Instant now = Instant.now();
        Jwt jwt = Jwt.withTokenValue("signed-token")
                .header("alg", "RS256")
                .subject("service-bad")
                .issuedAt(now.minusSeconds(2))
                .expiresAt(now.plusSeconds(60))
                .audience(List.of("standup-api"))
                .claim("roles", List.of("BAD"))
                .claim("idEspositore", "ESP-42")
                .build();
        OidcTokens tokens = new OidcTokens(token -> jwt, "roles", "idEspositore");

        Map<String, Object> claims = tokens.authenticate("signed-token");

        assertEquals("service-bad", claims.get("sub"));
        assertEquals("BAD", claims.get("role"));
        assertEquals("ESP-42", claims.get("idEspositore"));
    }

    @Test
    void rejectsAmbiguousRolesAndUnknownRoleNames() {
        Instant now = Instant.now();
        for (Object roles : List.of(List.of("BAD", "STAFF"), "ROOT")) {
            Jwt jwt = Jwt.withTokenValue("signed-token")
                    .header("alg", "RS256")
                    .subject("service")
                    .issuedAt(now.minusSeconds(2))
                    .expiresAt(now.plusSeconds(60))
                    .claim("roles", roles)
                    .build();
            OidcTokens tokens = new OidcTokens(token -> jwt, "roles", "idEspositore");

            assertThrows(JwtException.class, () -> tokens.authenticate("signed-token"));
        }
    }
}
