package standup.api;

import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Keeps validation, authorization and database conflict errors in one response shape. */
@RestControllerAdvice
public class ApiFailureHandler {
    private static final Logger log = LoggerFactory.getLogger(ApiFailureHandler.class);

    @ExceptionHandler(ApiFailure.class)
    public ResponseEntity<Map<String, Object>> handle(ApiFailure error, HttpServletRequest request) {
        return problem(error.status(), error.code(), error.getMessage(), request);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<Map<String, Object>> methodNotAllowed(HttpRequestMethodNotSupportedException error, HttpServletRequest request) {
        return problem(405, "METODO_NON_AMMESSO", "Il metodo HTTP non è previsto per questa rotta.", request);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> unexpected(Exception error, HttpServletRequest request) {
        log.error("Unhandled API error method={} path={}", request.getMethod(), request.getRequestURI(), error);
        return problem(500, "ERRORE_INTERNO", "Si è verificato un errore interno. Usa il requestId per la diagnosi.", request);
    }

    private ResponseEntity<Map<String, Object>> problem(int status, String code, String detail, HttpServletRequest request) {
        String id = UUID.randomUUID().toString();
        return ResponseEntity.status(HttpStatusCode.valueOf(status)).body(Map.of(
                "type", "about:blank", "title", title(status), "status", status,
                "code", code, "detail", detail, "requestId", id,
                "instance", request.getRequestURI(), "timestamp", Instant.now().toString()));
    }

    private String title(int status) {
        return switch (status) {
            case 400 -> "Richiesta non valida";
            case 401 -> "Autenticazione richiesta";
            case 403 -> "Operazione non autorizzata";
            case 404 -> "Risorsa non trovata";
            case 409 -> "Conflitto";
            case 429 -> "Troppe richieste";
            default -> "Errore del server";
        };
    }
}
