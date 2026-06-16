package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.ezddd.cqrs.usecase.query.ProjectionInput;

public record ProductReadOnlyProjectionInput(String productId) implements ProjectionInput {
}
