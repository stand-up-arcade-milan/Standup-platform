package standup;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Application entry point; domain modules can be added under this package later. */
@SpringBootApplication
public class StandupPlatformApplication {

    public static void main(String[] args) {
        SpringApplication.run(StandupPlatformApplication.class, args);
    }
}
