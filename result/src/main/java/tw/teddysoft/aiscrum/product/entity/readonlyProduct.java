package tw.teddysoft.aiscrum.product.entity;

import java.util.Objects;

public final class readonlyProduct {

    private final Product product;

    private readonlyProduct(Product product) {
        this.product = Objects.requireNonNull(product);
    }

    public static readonlyProduct from(Product product) {
        return new readonlyProduct(product);
    }

    public ProductId getId() {
        return product.getId();
    }

    public ProductName getName() {
        return product.getName();
    }

    public ProductGoal getGoal() {
        return product.getGoal();
    }

    public String getNote() {
        return product.getNote();
    }

    public String getExtension() {
        return product.getExtension();
    }

    public ProductLifecycleState getState() {
        return product.getState();
    }

    public void rename(ProductName newName, String userId) {
        throw new UnsupportedOperationException("readonlyProduct does not allow mutation");
    }
}
