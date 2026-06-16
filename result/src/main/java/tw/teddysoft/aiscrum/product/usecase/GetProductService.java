package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.usecase.port.ProductDtoProjection;
import tw.teddysoft.aiscrum.product.usecase.port.ProductDtoProjectionInput;

import java.util.NoSuchElementException;
import java.util.Objects;

public class GetProductService implements GetProductUseCase {

    private final ProductDtoProjection productDtoProjection;

    public GetProductService(ProductDtoProjection productDtoProjection) {
        this.productDtoProjection = Objects.requireNonNull(productDtoProjection);
    }

    @Override
    public GetProductOutput execute(GetProductInput input) {
        return productDtoProjection.query(new ProductDtoProjectionInput(input.productId))
                .map(product -> new GetProductOutput()
                        .setProduct(product)
                        .setId(input.productId)
                        .succeed())
                .orElseThrow(() -> new NoSuchElementException("Product not found: " + input.productId));
    }
}
