package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.readonlyProduct;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import java.util.Objects;

import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class GetProductService implements GetProductUseCase {

    private final ProductRepository productRepository;

    public GetProductService(ProductRepository productRepository) {
        this.productRepository = Objects.requireNonNull(productRepository);
    }

    @Override
    public GetProductOutput execute(GetProductInput input) {
        requireNotNull("Input", input);
        requireNotNull("Product id", input.productId);

        return productRepository.findById(ProductId.valueOf(input.productId))
                .map(product -> new GetProductOutput()
                        .setReadonlyProduct(readonlyProduct.from(product))
                        .setId(input.productId)
                        .setExitCode(ExitCode.SUCCESS))
                .orElseGet(() -> new GetProductOutput()
                        .setId(input.productId)
                        .setMessage("Get product failed: product not found, product id = " + input.productId)
                        .setExitCode(ExitCode.FAILURE));
    }
}
