package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.usecase.port.ProductDto;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.query.Query;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface GetProductUseCase extends Query<GetProductUseCase.GetProductInput, GetProductUseCase.GetProductOutput> {

    class GetProductInput implements Input {
        public String productId;

        public static GetProductInput create(String productId) {
            GetProductInput input = new GetProductInput();
            input.productId = productId;
            return input;
        }

        public static GetProductInput create() {
            return new GetProductInput();
        }
    }

    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private ProductDto product;

        public ProductDto getProduct() {
            return product;
        }

        public GetProductOutput setProduct(ProductDto product) {
            this.product = product;
            return this;
        }
    }
}
