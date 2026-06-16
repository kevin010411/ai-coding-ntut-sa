package tw.teddysoft.aiscrum.product.entity;

import java.util.Objects;

public class ProductReadOnly implements ProductReadable {

    private final ProductReadable product;

    private ProductReadOnly(ProductReadable product) {
        this.product = Objects.requireNonNull(product);
    }

    public static ProductReadOnly from(ProductReadable product) {
        if (product instanceof ProductReadOnly readOnly) {
            return readOnly;
        }
        return new ProductReadOnly(product);
    }

    @Override
    public ProductId getId() {
        return product.getId();
    }

    @Override
    public ProductName getName() {
        return product.getName();
    }

    @Override
    public ProductGoalReadOnly getGoal() {
        return ProductGoalReadOnly.from(product.getGoal());
    }

    @Override
    public String getNote() {
        return product.getNote();
    }

    @Override
    public String getExtension() {
        return product.getExtension();
    }

    @Override
    public ProductLifecycleState getState() {
        return product.getState();
    }

    public void rejectMutation() {
        throw new UnsupportedOperationException("ProductReadOnly does not allow mutation");
    }
}
