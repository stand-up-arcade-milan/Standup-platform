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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Small HS256 token issuer for exhibitor invitations and the local development simulator. */
@Component
public class ApiTokens {
    private final ObjectMapper json;
    private final byte[] secret;

    public ApiTokens(ObjectMapper json, @Value("${arcade.jwt-secret:local-development-secret-change-me-32-bytes}") String secret) {
        this.json = json;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        if (this.secret.length < 32) throw new IllegalArgumentException("arcade.jwt-secret deve contenere almeno 32 byte");
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
            throw new IllegalStateException("Impossibile emettere il token", exception);
        }
    }

    public Map<String, Object> authenticate(HttpServletRequest request, String... allowedRoles) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith("Bearer ")) throw new ApiFailure(401, "TOKEN_MANCANTE", "È richiesto un bearer token.");
        try {
            String[] parts = authorization.substring(7).split("\\.");
            if (parts.length != 3) throw new IllegalArgumentException("JWT malformato");
            Map<String, Object> header = json.readValue(Base64.getUrlDecoder().decode(parts[0]), new TypeReference<>() {});
            if (!"HS256".equals(header.get("alg"))) throw new IllegalArgumentException("Algoritmo non ammesso");
            byte[] signature = Base64.getUrlDecoder().decode(parts[2]);
            if (!MessageDigest.isEqual(signature, sign(parts[0] + "." + parts[1]))) throw new IllegalArgumentException("Firma non valida");
            Map<String, Object> claims = json.readValue(Base64.getUrlDecoder().decode(parts[1]), new TypeReference<>() {});
            if (!(claims.get("exp") instanceof Number expires) || expires.longValue() <= Instant.now().getEpochSecond()) throw new IllegalArgumentException("Token scaduto");
            String role = String.valueOf(claims.get("role"));
            for (String allowed : allowedRoles) if (allowed.equals(role)) return claims;
            throw new ApiFailure(403, "RUOLO_NON_AUTORIZZATO", "Il ruolo del token non può eseguire questa operazione.");
        } catch (ApiFailure error) {
            throw error;
        } catch (Exception exception) {
            throw new ApiFailure(401, "TOKEN_NON_VALIDO", "Il bearer token non è valido o è scaduto.");
        }
    }

    public String hash(String value) {
        try {
            return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }

    /** Stable keyed fingerprint for ticket references that must not be stored in clear text. */
    public String fingerprint(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return java.util.HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        }
        catch (Exception exception) { throw new IllegalStateException(exception); }
    }

    private String encode(byte[] value) { return Base64.getUrlEncoder().withoutPadding().encodeToString(value); }
    private byte[] sign(String value) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret, "HmacSHA256"));
        return mac.doFinal(value.getBytes(StandardCharsets.US_ASCII));
    }
}
