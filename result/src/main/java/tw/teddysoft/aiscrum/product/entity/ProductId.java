package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.util.Objects;
import java.util.UUID;

public record ProductId(String value) implements ValueObject {

    public ProductId {
        Objects.requireNonNull(value, "ProductId value cannot be null");
    }

    public static ProductId valueOf(String value) {
        return new ProductId(value);
    }

    public static ProductId valueOf(UUID uuid) {
        return new ProductId(uuid.toString());
    }

    public static ProductId create() {
        return valueOf(UUID.randomUUID());
    }

    @Override
    public String toString() {
        return value;
    }
}
