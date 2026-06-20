package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.ProductName;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;
import tw.teddysoft.ezddd.usecase.port.in.interactor.UseCaseFailureException;

import java.util.Objects;

import static tw.teddysoft.ucontract.Contract.requireNotNull;

public class RenameProductService implements RenameProductUseCase {

    private final ProductRepository productRepository;

    public RenameProductService(ProductRepository productRepository) {
        this.productRepository = Objects.requireNonNull(productRepository);
    }

    @Override
    public CqrsOutput<?> execute(RenameProductInput input) {
        requireNotNull("Input", input);
        requireNotNull("Product id", input.productId);
        requireNotNull("New name", input.newName);
        requireNotNull("User id", input.userId);

        try {
            ProductId productId = ProductId.valueOf(input.productId);
            var product = productRepository.findById(productId).orElse(null);
            if (product == null) {
                return CqrsOutput.create()
                        .setId(input.productId)
                        .setMessage("Rename product failed: product not found, product id = " + input.productId)
                        .setExitCode(ExitCode.FAILURE);
            }

            product.rename(ProductName.valueOf(input.newName), input.userId);
            productRepository.save(product);
            return CqrsOutput.create()
                    .setId(input.productId)
                    .setExitCode(ExitCode.SUCCESS);
        } catch (Exception e) {
            throw new UseCaseFailureException(e);
        }
    }
}
