package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.aiscrum.product.entity.ProductGoal;
import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.entity.ProductLifecycleState;
import tw.teddysoft.aiscrum.product.entity.ProductName;

import java.util.Optional;

public record ProductDto(
        ProductId id,
        ProductName name,
        ProductGoal goal,
        Optional<DefinitionOfDoneDto> definitionOfDone,
        String note,
        String extension,
        ProductLifecycleState state
) {
}
