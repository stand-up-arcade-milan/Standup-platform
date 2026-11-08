package standup.api;

/** Exception translated to the stable RFC 7807 style used by openapi.yaml. */
public final class ApiFailure extends RuntimeException {
    private final int status;
    private final String code;

    public ApiFailure(int status, String code, String detail) {
        super(detail);
        this.status = status;
        this.code = code;
    }

    public int status() { return status; }
    public String code() { return code; }
}
