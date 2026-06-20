package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.aiscrum.common.entity.DateProvider;
import tw.teddysoft.ezddd.entity.EsAggregateRoot;

import java.util.HashMap;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

import static tw.teddysoft.ucontract.Contract.ensure;
import static tw.teddysoft.ucontract.Contract.require;
import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class Product extends EsAggregateRoot<ProductId, ProductEvents> {

    public static final String CATEGORY = "Product";

    private ProductId id;
    private ProductName name;
    private ProductGoal goal;
    private String note;
    private String extension;
    private ProductLifecycleState state;

    public Product(List<ProductEvents> domainEvents) {
        super(domainEvents);
    }

    public Product(ProductId id, ProductName name) {
        super();
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

        ensure("Product id is set correctly", () -> Objects.equals(this.id, id));
        ensure("Product name is set correctly", () -> Objects.equals(this.name, name));
        ensure("Product state is DRAFT initially", () -> ProductLifecycleState.DRAFT == this.state);
        ensure("ProductCreated event generated", this::_productCreatedEventGenerated);
    }

    public void rename(ProductName newName, String userId) {
        require("Not deleted", () -> !this.isDeleted);
        requireNotNull("newName", newName);

        ProductName oldName = this.name;
        apply(new ProductEvents.ProductRenamed(
                this.id,
                oldName,
                newName,
                new HashMap<>(),
                UUID.randomUUID(),
                DateProvider.now()));

        ensure("Name matches", () -> Objects.equals(this.name, newName));
        ensure("ProductRenamed event generated", () -> _productRenamedEventGenerated(oldName, newName));
    }

    @Override
    protected void when(ProductEvents event) {
        switch (event) {
            case ProductEvents.ProductCreated e -> when(e);
            case ProductEvents.ProductRenamed e -> when(e);
        }
    }

    private void when(ProductEvents.ProductCreated event) {
        this.id = event.productId();
        this.name = event.name();
        this.goal = event.goal();
        this.note = event.note();
        this.extension = event.extension();
        this.state = event.state();
    }

    private void when(ProductEvents.ProductRenamed event) {
        this.name = event.newName();
    }

    @Override
    public ProductId getId() {
        return id;
    }

    @Override
    public String getCategory() {
        return CATEGORY;
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

    private boolean _productCreatedEventGenerated() {
        return getDomainEvents().stream()
                .anyMatch(event -> event instanceof ProductEvents.ProductCreated created
                        && Objects.equals(created.productId(), id)
                        && Objects.equals(created.name(), name)
                        && created.state() == state);
    }

    private boolean _productRenamedEventGenerated(ProductName oldName, ProductName newName) {
        return getDomainEvents().stream()
                .anyMatch(event -> event instanceof ProductEvents.ProductRenamed renamed
                        && Objects.equals(renamed.productId(), id)
                        && Objects.equals(renamed.oldName(), oldName)
                        && Objects.equals(renamed.newName(), newName));
    }
}
