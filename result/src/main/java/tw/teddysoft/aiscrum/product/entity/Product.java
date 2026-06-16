package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.aiscrum.common.entity.DateProvider;
import tw.teddysoft.ezddd.entity.EsAggregateRoot;

import java.util.HashMap;
import java.util.UUID;

import static tw.teddysoft.ucontract.Contract.ensure;
import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class Product extends EsAggregateRoot<ProductId, ProductEvents> {

    private ProductId id;
    private ProductName name;
    private ProductGoal goal;
    private String note;
    private String extension;
    private ProductLifecycleState state;

    public Product(ProductId id, ProductName name) {
        requireNotNull("id", id);
        requireNotNull("name", name);

        apply(new ProductEvents.ProductCreated(
                id,
                name,
                null,
                null,
                null,
                ProductLifecycleState.DRAFT,
                new HashMap<>(),
                UUID.randomUUID(),
                DateProvider.now()));

        ensure("Product id is set correctly", () -> id.equals(this.id));
        ensure("Product name is set correctly", () -> name.equals(this.name));
        ensure("Product state is DRAFT initially", () -> ProductLifecycleState.DRAFT == this.state);
    }

    @Override
    public ProductId getId() {
        return id;
    }

    @Override
    public String getCategory() {
        return "Product";
    }

    public ProductName getName() {
        return name;
    }

    public ProductGoal getGoal() {
        return goal;
    }

    public String getNote() {
        return note;
    }

    public String getExtension() {
        return extension;
    }

    public ProductLifecycleState getState() {
        return state;
    }

    @Override
    protected void when(ProductEvents event) {
        switch (event) {
            case ProductEvents.ProductCreated created -> {
                this.id = created.productId();
                this.name = created.name();
                this.goal = created.goal();
                this.note = created.note();
                this.extension = created.extension();
                this.state = created.state();
            }
        }
    }
}
