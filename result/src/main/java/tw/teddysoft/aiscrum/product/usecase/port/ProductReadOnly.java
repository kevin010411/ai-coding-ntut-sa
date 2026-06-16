package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductGoal;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.ProductLifecycleState;
import tw.teddysoft.aiscrum.product.entity.ProductName;

import java.util.Objects;

public class ProductReadOnly {

    private final Product delegate;

    private ProductReadOnly(Product delegate) {
        this.delegate = Objects.requireNonNull(delegate);
    }

    public static ProductReadOnly from(Product product) {
        return new ProductReadOnly(product);
    }

    public ProductId getId() {
        return delegate.getId();
    }

    public ProductName getName() {
        return delegate.getName();
    }

    public ProductGoal getGoal() {
        return delegate.getGoal();
    }

    public String getNote() {
        return delegate.getNote();
    }

    public String getExtension() {
        return delegate.getExtension();
    }

    public ProductLifecycleState getState() {
        return delegate.getState();
    }
}
