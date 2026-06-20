package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.math.BigDecimal;
import java.util.Objects;

public record GoalMetric(
        String name,
        String unit,
        BigDecimal targetValue,
        BigDecimal currentValue,
        boolean isKey
) implements ValueObject {

    public GoalMetric {
        Objects.requireNonNull(name, "name cannot be null");
        Objects.requireNonNull(unit, "unit cannot be null");
        Objects.requireNonNull(targetValue, "targetValue cannot be null");
        Objects.requireNonNull(currentValue, "currentValue cannot be null");
    }
}
