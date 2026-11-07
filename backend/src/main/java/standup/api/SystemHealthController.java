package standup.api;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Minimal API route used to verify that the frontend can reach Spring Boot. */
@RestController
@RequestMapping("/api/v1/health")
public class SystemHealthController {

    @GetMapping
    public ApiHealth getHealth() {
        // Database connectivity is reported separately by Spring Boot Actuator.
        return new ApiHealth("standup-platform-api", "UP");
    }

    /** Stable response shape for the boilerplate health route. */
    public record ApiHealth(String service, String status) {
    }
}
