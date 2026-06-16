package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnly;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

import java.util.NoSuchElementException;
import java.util.Objects;

public class GetProductService implements GetProductUseCase {

    private final ProductRepository productRepository;

    public GetProductService(ProductRepository productRepository) {
        this.productRepository = Objects.requireNonNull(productRepository);
    }

    @Override
    public GetProductOutput execute(GetProductInput input) {
        return productRepository.findById(ProductId.valueOf(input.productId))
                .map(ProductReadOnly::from)
                .map(readOnlyProduct -> new GetProductOutput()
                        .setProduct(readOnlyProduct)
                        .setId(input.productId)
                        .succeed())
                .orElseThrow(() -> new NoSuchElementException("Product not found: " + input.productId));
    }
}
