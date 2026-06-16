package tw.teddysoft.aiscrum.product.usecase;

import java.util.NoSuchElementException;
import java.util.Objects;

import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnlyProjection;
import tw.teddysoft.aiscrum.product.usecase.port.ProductReadOnlyProjectionInput;

public class GetProductService implements GetProductUseCase {

    private final ProductReadOnlyProjection productReadOnlyProjection;

    public GetProductService(ProductReadOnlyProjection productReadOnlyProjection) {
        this.productReadOnlyProjection = Objects.requireNonNull(productReadOnlyProjection);
    }

    @Override
    public GetProductOutput execute(GetProductInput input) {
        return productReadOnlyProjection.query(new ProductReadOnlyProjectionInput(input.productId))
                .map(product -> new GetProductOutput()
                        .setProduct(product)
                        .setId(input.productId)
                        .succeed())
                .orElseThrow(() -> new NoSuchElementException("Product not found: " + input.productId));
    }
}
