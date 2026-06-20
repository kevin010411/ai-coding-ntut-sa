package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.aiscrum.product.entity.readonlyProduct;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.query.Query;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface GetProductUseCase extends Query<GetProductUseCase.GetProductInput, GetProductUseCase.GetProductOutput> {

    class GetProductInput implements Input {
        public String productId;

        public static GetProductInput create() {
            return new GetProductInput();
        }

        public static GetProductInput create(String productId) {
            GetProductInput input = create();
            input.productId = productId;
            return input;
        }
    }

    class GetProductOutput extends CqrsOutput<GetProductOutput> {
        private readonlyProduct readonlyProduct;

        public readonlyProduct getReadonlyProduct() {
            return readonlyProduct;
        }

        public GetProductOutput setReadonlyProduct(readonlyProduct readonlyProduct) {
            this.readonlyProduct = readonlyProduct;
            return this;
        }
    }
}
