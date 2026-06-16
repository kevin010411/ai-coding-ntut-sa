package tw.teddysoft.aiscrum.product.adapter.out.projection.inmemory;

import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.ProductReadOnly;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnlyProjection;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnlyProjectionInput;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

import java.util.Objects;
import java.util.Optional;

public class InMemoryProductReadOnlyProjection implements ProductReadOnlyProjection {

    private final ProductRepository productRepository;

    public InMemoryProductReadOnlyProjection(ProductRepository productRepository) {
        this.productRepository = Objects.requireNonNull(productRepository);
    }

    @Override
    public Optional<ProductReadOnly> query(ProductReadOnlyProjectionInput input) {
        return productRepository.findById(ProductId.valueOf(input.productId()))
                .map(ProductReadOnly::from);
    }
}
