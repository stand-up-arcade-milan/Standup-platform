package standup.api;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/** Stores only keyed email/IP fingerprints; writes commit independently of failed login responses. */
@Component
public class LoginRateLimiter {
    private final JdbcTemplate db;
    private final TransactionTemplate independentTransaction;

    @Autowired
    public LoginRateLimiter(JdbcTemplate db, PlatformTransactionManager transactionManager) {
        this.db = db;
        this.independentTransaction = new TransactionTemplate(transactionManager);
        this.independentTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    }

    LoginRateLimiter() {
        this.db = null;
        this.independentTransaction = null;
    }

    public boolean blocked(String rateKey) {
        if (independentTransaction == null) return false;
        return independentTransaction.execute(status -> {
            selectAuthenticationRole();
            db.update("DELETE FROM arcade.auth_login_rate_limit WHERE last_attempt < now() - interval '24 hours'");
            return db.queryForObject("SELECT EXISTS (SELECT 1 FROM arcade.auth_login_rate_limit WHERE rate_key=? AND blocked_until>now())", Boolean.class, rateKey);
        });
    }

    public void failed(String rateKey) {
        if (independentTransaction == null) return;
        independentTransaction.executeWithoutResult(status -> {
            selectAuthenticationRole();
            db.update("""
                    INSERT INTO arcade.auth_login_rate_limit(rate_key,window_started,attempt_count,last_attempt)
                    VALUES(?,now(),1,now())
                    ON CONFLICT (rate_key) DO UPDATE SET
                      window_started = CASE
                        WHEN arcade.auth_login_rate_limit.window_started < now() - interval '15 minutes' THEN now()
                        ELSE arcade.auth_login_rate_limit.window_started END,
                      attempt_count = CASE
                        WHEN arcade.auth_login_rate_limit.window_started < now() - interval '15 minutes' THEN 1
                        ELSE arcade.auth_login_rate_limit.attempt_count + 1 END,
                      blocked_until = CASE
                        WHEN arcade.auth_login_rate_limit.window_started < now() - interval '15 minutes' THEN NULL
                        WHEN arcade.auth_login_rate_limit.attempt_count >= 4 THEN now() + interval '15 minutes'
                        ELSE arcade.auth_login_rate_limit.blocked_until END,
                      last_attempt = now()
                    """, rateKey);
        });
    }

    public void succeeded(String rateKey) {
        if (independentTransaction == null) return;
        independentTransaction.executeWithoutResult(status -> {
            selectAuthenticationRole();
            db.update("DELETE FROM arcade.auth_login_rate_limit WHERE rate_key=?", rateKey);
        });
    }

    private void selectAuthenticationRole() {
        db.execute("SET LOCAL ROLE arcade_autenticazione");
    }
}
