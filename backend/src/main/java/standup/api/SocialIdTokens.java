package standup.api;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Component;

/**
 * Verifica gli ID token di Google e Microsoft contro le chiavi pubbliche del fornitore.
 *
 * <p>Serve l'accesso con un account aziendale dalla schermata Accesso. Il client manda solo
 * l'ID token: l'identificativo stabile della persona e la sua email si leggono dal token
 * verificato, mai dal corpo della richiesta, altrimenti chiunque potrebbe dichiarare l'email
 * di un altro espositore e farsi emettere il suo token.
 *
 * <p>Se il client id del fornitore non e configurato, quel fornitore resta spento e la
 * richiesta riceve 503 invece di un accesso non verificato.
 */
@Component
public class SocialIdTokens {
    private static final String GOOGLE_ISSUER = "https://accounts.google.com";
    private static final String GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs";
    private static final String MICROSOFT_JWKS = "https://login.microsoftonline.com/common/discovery/v2.0/keys";
    /** Con il tenant "common" l'issuer contiene il tenant di chi entra, quindi si verifica la forma. */
    private static final Pattern MICROSOFT_ISSUER =
            Pattern.compile("https://login\\.microsoftonline\\.com/[0-9a-fA-F-]{36}/v2\\.0");

    private final JwtDecoder google;
    private final JwtDecoder microsoft;

    public SocialIdTokens(
            @Value("${arcade.social.google.client-id:}") String googleClientId,
            @Value("${arcade.social.microsoft.client-id:}") String microsoftClientId) {
        this.google = googleClientId.isBlank() ? null : googleDecoder(googleClientId);
        this.microsoft = microsoftClientId.isBlank() ? null : microsoftDecoder(microsoftClientId);
    }

    SocialIdTokens(JwtDecoder google, JwtDecoder microsoft) {
        this.google = google;
        this.microsoft = microsoft;
    }

    public boolean isEnabled(String fornitore) {
        return decoder(fornitore) != null;
    }

    /**
     * Ritorna subject ed email presi dal token verificato.
     *
     * @throws ApiFailure 503 se il fornitore non e configurato, 401 se il token non e valido
     */
    public Map<String, String> verify(String fornitore, String idToken) {
        JwtDecoder decoder = decoder(fornitore);
        if (decoder == null) {
            throw new ApiFailure(503, "ACCESSO_ESTERNO_NON_CONFIGURATO",
                    "L'accesso con " + fornitore + " non e configurato su questo ambiente.");
        }
        Jwt jwt;
        try {
            jwt = decoder.decode(idToken);
        } catch (JwtException e) {
            throw new ApiFailure(401, "TOKEN_ESTERNO_NON_VALIDO", "Il token del fornitore non e valido.");
        }
        String subject = jwt.getSubject();
        if (subject == null || subject.isBlank()) {
            throw new ApiFailure(401, "TOKEN_ESTERNO_NON_VALIDO", "Il token del fornitore non ha un subject.");
        }
        String email = claim(jwt, "email");
        if (email == null) email = claim(jwt, "preferred_username");
        if (email == null || !email.contains("@")) {
            throw new ApiFailure(401, "EMAIL_ASSENTE", "Il token del fornitore non contiene un'email.");
        }
        if (Boolean.FALSE.equals(jwt.getClaims().get("email_verified"))) {
            throw new ApiFailure(401, "EMAIL_NON_VERIFICATA", "Il fornitore non ha verificato questa email.");
        }
        Map<String, String> identita = new LinkedHashMap<>();
        identita.put("subject", subject);
        identita.put("email", email.trim().toLowerCase());
        return identita;
    }

    private JwtDecoder decoder(String fornitore) {
        return switch (fornitore) {
            case "GOOGLE" -> google;
            case "MICROSOFT" -> microsoft;
            default -> null;
        };
    }

    private static String claim(Jwt jwt, String nome) {
        return jwt.getClaims().get(nome) instanceof String value && !value.isBlank() ? value : null;
    }

    private static JwtDecoder googleDecoder(String clientId) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(GOOGLE_JWKS)
                .jwsAlgorithm(SignatureAlgorithm.RS256)
                .build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                new JwtTimestampValidator(),
                issuerIsOneOf(GOOGLE_ISSUER, "accounts.google.com"),
                audienceIs(clientId)));
        return decoder;
    }

    private static JwtDecoder microsoftDecoder(String clientId) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(MICROSOFT_JWKS)
                .jwsAlgorithm(SignatureAlgorithm.RS256)
                .build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                new JwtTimestampValidator(),
                issuerMatches(MICROSOFT_ISSUER),
                audienceIs(clientId)));
        return decoder;
    }

    private static OAuth2TokenValidator<Jwt> audienceIs(String clientId) {
        return token -> token.getAudience() != null && token.getAudience().contains(clientId)
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(
                        new OAuth2Error("invalid_token", "Il token non e stato emesso per questa applicazione.", null));
    }

    private static OAuth2TokenValidator<Jwt> issuerIsOneOf(String... ammessi) {
        return token -> {
            String issuer = token.getIssuer() == null ? null : token.getIssuer().toString();
            for (String ammesso : ammessi) {
                if (ammesso.equals(issuer)) return OAuth2TokenValidatorResult.success();
            }
            return OAuth2TokenValidatorResult.failure(
                    new OAuth2Error("invalid_token", "Emittente del token non ammesso.", null));
        };
    }

    private static OAuth2TokenValidator<Jwt> issuerMatches(Pattern forma) {
        return token -> {
            String issuer = token.getIssuer() == null ? null : token.getIssuer().toString();
            return issuer != null && forma.matcher(issuer).matches()
                    ? OAuth2TokenValidatorResult.success()
                    : OAuth2TokenValidatorResult.failure(
                            new OAuth2Error("invalid_token", "Emittente del token non ammesso.", null));
        };
    }
}
