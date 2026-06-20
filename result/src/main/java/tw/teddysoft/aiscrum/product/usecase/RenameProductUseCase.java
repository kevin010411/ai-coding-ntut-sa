package tw.teddysoft.aiscrum.product.usecase;

import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.cqrs.usecase.command.Command;
import tw.teddysoft.ezddd.usecase.port.in.interactor.Input;

public interface RenameProductUseCase extends Command<RenameProductUseCase.RenameProductInput, CqrsOutput<?>> {

    class RenameProductInput implements Input {
        public String productId;
        public String newName;
        public String userId;

        public static RenameProductInput create() {
            return new RenameProductInput();
        }

        public static RenameProductInput create(String productId, String newName, String userId) {
            RenameProductInput input = create();
            input.productId = productId;
            input.newName = newName;
            input.userId = userId;
            return input;
        }
    }
}
