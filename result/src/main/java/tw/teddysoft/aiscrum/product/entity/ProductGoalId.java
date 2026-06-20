package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.util.Objects;
import java.util.UUID;

public record ProductGoalId(String value) implements ValueObject {

    public ProductGoalId {
        Objects.requireNonNull(value, "ProductGoalId value cannot be null");
    }

    public static ProductGoalId create() {
        return new ProductGoalId(UUID.randomUUID().toString());
    }

    public static ProductGoalId valueOf(String value) {
        return new ProductGoalId(value);
    }

    public static ProductGoalId valueOf(UUID value) {
        return new ProductGoalId(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}
