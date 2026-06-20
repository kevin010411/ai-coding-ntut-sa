package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.util.Objects;
import java.util.UUID;

public record ProductId(String value) implements ValueObject {

    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
    }

    public static ProductId create() {
        return new ProductId(UUID.randomUUID().toString());
    }

    public static ProductId valueOf(String value) {
        return new ProductId(value);
    }

    public static ProductId valueOf(UUID value) {
        return new ProductId(value.toString());
    }

    @Override
    public String toString() {
        return value;
    }
}
