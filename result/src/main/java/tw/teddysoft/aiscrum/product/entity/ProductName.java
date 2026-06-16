package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.ValueObject;

import java.util.Objects;

public record ProductName(String value) implements ValueObject {

    public ProductName {
        Objects.requireNonNull(value, "ProductName value cannot be null");
    }

    public static ProductName valueOf(String value) {
        return new ProductName(value);
    }

    @Override
    public String toString() {
        return value;
    }
}
