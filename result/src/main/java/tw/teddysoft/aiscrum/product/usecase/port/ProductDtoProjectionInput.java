package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;

public record ProductDtoProjectionInput(String productId) implements ProjectionInput {
}
