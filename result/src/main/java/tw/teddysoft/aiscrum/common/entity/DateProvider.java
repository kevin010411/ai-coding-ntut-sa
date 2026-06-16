package tw.teddysoft.aiscrum.common.entity;

import java.time.Instant;

public class DateProvider {

    private static Instant fixedInstant;

    public static Instant now() {
        return fixedInstant != null ? fixedInstant : Instant.now();
    }

    public static void useFixedInstant(Instant instant) {
        fixedInstant = instant;
    }

    public static void useSystemTime() {
        fixedInstant = null;
    }
}
