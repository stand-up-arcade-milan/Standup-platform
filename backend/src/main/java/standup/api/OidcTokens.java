package standup.api;

import java.net.URI;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

/** Verifies enterprise access tokens; role values must match the API role names. */
@Component
public class OidcTokens {
    private static final Set<String> API_ROLES = Set.of(
            "ESPOSITORE", "COMMERCIALE", "STAFF", "AMMINISTRATORE", "DIREZIONE", "DEVICE", "BAD");

    private final JwtDecoder decoder;
    private final String rolesClaim;
    private final String exhibitorIdClaim;

    @Autowired
    public OidcTokens(
            @Value("${arcade.oidc.issuer-uri:}") String issuer,
            @Value("${arcade.oidc.jwk-set-uri:}") String jwkSetUri,
            @Value("${arcade.oidc.audience:}") String audience,
            @Value("${arcade.oidc.roles-claim:roles}") String rolesClaim,
            @Value("${arcade.oidc.exhibitor-id-claim:idEspositore}") String exhibitorIdClaim,
            @Value("${arcade.auth.local-tokens-enabled:false}") boolean localTokensEnabled) {
        this.rolesClaim = rolesClaim;
        this.exhibitorIdClaim = exhibitorIdClaim;
        boolean configured = !issuer.isBlank() || !jwkSetUri.isBlank() || !audience.isBlank();
        if (!configured) {
            if (!localTokensEnabled) throw new IllegalStateException("Configure OIDC or enable local tokens only for development.");
            this.decoder = null;
            return;
        }
        if (issuer.isBlank() || jwkSetUri.isBlank() || audience.isBlank()) {
            throw new IllegalStateException("OIDC requires issuer-uri, jwk-set-uri, and audience.");
        }
        requireSecureUri(issuer, "issuer-uri");
        requireSecureUri(jwkSetUri, "jwk-set-uri");
        NimbusJwtDecoder oidcDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri)
                .jwsAlgorithm(SignatureAlgorithm.RS256)
                .build();
        OAuth2TokenValidator<Jwt> audienceValidator = token -> token.getAudience().contains(audience)
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "JWT audience is not allowed.", null));
        oidcDecoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefaultWithIssuer(issuer), audienceValidator));
        this.decoder = oidcDecoder;
    }

    OidcTokens(JwtDecoder decoder, String rolesClaim, String exhibitorIdClaim) {
        this.decoder = decoder;
        this.rolesClaim = rolesClaim;
        this.exhibitorIdClaim = exhibitorIdClaim;
    }

    public Map<String, Object> authenticate(String token) {
        if (decoder == null) throw new JwtException("OIDC is not configured.");
        Jwt jwt = decoder.decode(token);
        if (jwt.getSubject() == null || jwt.getSubject().isBlank()) throw new JwtException("JWT has no subject.");
        String role = role(jwt.getClaims().get(rolesClaim));
        if (role == null || !API_ROLES.contains(role)) throw new JwtException("JWT has no single recognized API role.");

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("sub", jwt.getSubject());
        claims.put("role", role);
        Object exhibitorId = jwt.getClaims().get(exhibitorIdClaim);
        if (exhibitorId instanceof String value && !value.isBlank()) claims.put("idEspositore", value);
        return claims;
    }

    private String role(Object value) {
        if (value instanceof String name) return name.trim().toUpperCase();
        if (value instanceof List<?> names) {
            List<String> roles = names.stream()
                    .filter(String.class::isInstance)
                    .map(String.class::cast)
                    .map(String::trim)
                    .map(String::toUpperCase)
                    .filter(API_ROLES::contains)
                    .distinct()
                    .toList();
            return roles.size() == 1 ? roles.getFirst() : null;
        }
        return null;
    }

    private static void requireSecureUri(String value, String property) {
        URI uri = URI.create(value);
        String host = uri.getHost();
        boolean localHost = "localhost".equalsIgnoreCase(host) || "127.0.0.1".equals(host) || "::1".equals(host);
        if (!"https".equalsIgnoreCase(uri.getScheme()) && !("http".equalsIgnoreCase(uri.getScheme()) && localHost)) {
            throw new IllegalStateException("OIDC " + property + " must use HTTPS except on localhost.");
        }
    }
}
