package standup.api;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Issues exhibitor tokens and verifies local-development or enterprise JWTs. */
@Component
public class ApiTokens {
    private final ObjectMapper json;
    private final byte[] secret;
    private final OidcTokens oidcTokens;
    private final boolean localTokensEnabled;

    @Autowired
    public ApiTokens(
            ObjectMapper json,
            OidcTokens oidcTokens,
            @Value("${arcade.jwt-secret:}") String secret,
            @Value("${arcade.auth.local-tokens-enabled:false}") boolean localTokensEnabled) {
        this.json = json;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.oidcTokens = oidcTokens;
        this.localTokensEnabled = localTokensEnabled;
        if (this.secret.length < 32) throw new IllegalArgumentException("arcade.jwt-secret must contain at least 32 bytes");
    }

    ApiTokens(ObjectMapper json, String secret) {
        this.json = json;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.oidcTokens = null;
        this.localTokensEnabled = true;
        if (this.secret.length < 32) throw new IllegalArgumentException("arcade.jwt-secret must contain at least 32 bytes");
    }

    public String issue(String subject, String role, String exhibitorId, long seconds) {
        try {
            long now = Instant.now().getEpochSecond();
            String header = encode(json.writeValueAsBytes(Map.of("alg", "HS256", "typ", "JWT")));
            Map<String, Object> claims = new java.util.LinkedHashMap<>();
            claims.put("sub", subject);
            claims.put("role", role);
            claims.put("iat", now);
            claims.put("exp", now + seconds);
            if (exhibitorId != null) claims.put("idEspositore", exhibitorId);
            String payload = encode(json.writeValueAsBytes(claims));
            String content = header + "." + payload;
            return content + "." + Base64.getUrlEncoder().withoutPadding().encodeToString(sign(content));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to issue token", exception);
        }
    }

    public Map<String, Object> authenticate(HttpServletRequest request, String... allowedRoles) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new ApiFailure(401, "TOKEN_MANCANTE", "A bearer token is required.");
        }
        String raw = authorization.substring(7).trim();
        Map<String, Object> claims;
        try {
            claims = verifyLocal(raw);
            if (!localTokensEnabled && !"ESPOSITORE".equals(claims.get("role"))) {
                throw new IllegalArgumentException("Local HMAC tokens cannot authenticate internal roles.");
            }
        } catch (Exception localFailure) {
            if (oidcTokens == null) throw invalidToken();
            try {
                claims = oidcTokens.authenticate(raw);
            } catch (Exception oidcFailure) {
                throw invalidToken();
            }
        }
        String role = String.valueOf(claims.get("role"));
        for (String allowed : allowedRoles) if (allowed.equals(role)) return claims;
        throw new ApiFailure(403, "RUOLO_NON_AUTORIZZATO", "The token role cannot perform this operation.");
    }

    private Map<String, Object> verifyLocal(String token) throws Exception {
        String[] parts = token.split("\\.");
        if (parts.length != 3) throw new IllegalArgumentException("Malformed JWT");
        Map<String, Object> header = json.readValue(Base64.getUrlDecoder().decode(parts[0]), new TypeReference<>() {});
        if (!"HS256".equals(header.get("alg")) || !"JWT".equals(header.get("typ"))) throw new IllegalArgumentException("JWT algorithm not allowed");
        byte[] signature = Base64.getUrlDecoder().decode(parts[2]);
        if (!MessageDigest.isEqual(signature, sign(parts[0] + "." + parts[1]))) throw new IllegalArgumentException("Invalid signature");
        Map<String, Object> claims = json.readValue(Base64.getUrlDecoder().decode(parts[1]), new TypeReference<>() {});
        long now = Instant.now().getEpochSecond();
        if (!(claims.get("exp") instanceof Number expires) || expires.longValue() <= now) throw new IllegalArgumentException("Expired token");
        if (!(claims.get("iat") instanceof Number issued) || issued.longValue() > now + 60 || expires.longValue() <= issued.longValue()) throw new IllegalArgumentException("Invalid token interval");
        if (!(claims.get("sub") instanceof String subject) || subject.isBlank()) throw new IllegalArgumentException("Missing token subject");
        return claims;
    }

    private ApiFailure invalidToken() { return new ApiFailure(401, "TOKEN_NON_VALIDO", "The bearer token is invalid or expired."); }

    public String hash(String value) {
        try {
            return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }

    /** Stable keyed fingerprint for ticket references and pseudonymous audit actors. */
    public String fingerprint(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return java.util.HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private String encode(byte[] value) { return Base64.getUrlEncoder().withoutPadding().encodeToString(value); }
    private byte[] sign(String value) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret, "HmacSHA256"));
        return mac.doFinal(value.getBytes(StandardCharsets.US_ASCII));
    }
}