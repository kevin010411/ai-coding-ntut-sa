package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface CreateProductUseCase extends Command<CreateProductUseCase.CreateProductInput, CqrsOutput<?>> {

    class CreateProductInput implements Input {
        public String productId;
        public String name;
        public String userId;

        public static CreateProductInput create(String productId, String name, String userId) {
            CreateProductInput input = new CreateProductInput();
            input.productId = productId;
            input.name = name;
            input.userId = userId;
            return input;
        }

        public static CreateProductInput create() {
            return new CreateProductInput();
        }
    }
}
