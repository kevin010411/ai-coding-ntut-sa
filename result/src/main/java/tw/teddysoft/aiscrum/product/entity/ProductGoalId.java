package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.util.Objects;

public record ProductGoalId(String value) implements ValueObject {

    public ProductGoalId {
        Objects.requireNonNull(value, "ProductGoalId value cannot be null");
    }

    public static ProductGoalId valueOf(String value) {
        return new ProductGoalId(value);
    }
}
