package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.ProductName;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.UseCaseFailureException;

import java.util.Objects;

public class CreateProductService implements CreateProductUseCase {

    private final ProductRepository productRepository;

    public CreateProductService(ProductRepository productRepository) {
        this.productRepository = Objects.requireNonNull(productRepository);
    }

    @Override
    public CqrsOutput<?> execute(CreateProductInput input) {
        try {
            Product product = new Product(
                    ProductId.valueOf(input.productId),
                    ProductName.valueOf(input.name));
            productRepository.save(product);
            return CqrsOutput.create().setId(product.getId().value());
        } catch (Exception e) {
            throw new UseCaseFailureException(e);
        }
    }
}
