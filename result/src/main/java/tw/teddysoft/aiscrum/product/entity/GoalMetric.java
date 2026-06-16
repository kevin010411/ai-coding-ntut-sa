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
        Objects.requireNonNull(name, "GoalMetric name cannot be null");
        Objects.requireNonNull(unit, "GoalMetric unit cannot be null");
        Objects.requireNonNull(targetValue, "GoalMetric targetValue cannot be null");
        Objects.requireNonNull(currentValue, "GoalMetric currentValue cannot be null");
    }
}
