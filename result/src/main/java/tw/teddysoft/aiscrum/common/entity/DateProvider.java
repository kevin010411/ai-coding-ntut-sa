package tw.teddysoft.aiscrum.common.entity;

import java.time.Instant;
import java.util.Objects;
import java.util.function.Supplier;

public final class DateProvider {

    private static Supplier<Instant> clock = Instant::now;

    private DateProvider() {
    }

    public static Instant now() {
        return clock.get();
    }

    public static void useFixedTime(Instant fixedTime) {
        Objects.requireNonNull(fixedTime, "fixedTime cannot be null");
        clock = () -> fixedTime;
    }

    public static void useSystemTime() {
        clock = Instant::now;
    }
}
