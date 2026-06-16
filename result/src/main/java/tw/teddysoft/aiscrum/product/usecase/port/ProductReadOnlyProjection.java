package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.aiscrum.product.entity.ProductReadOnly;
import tw.teddysoft.ezddd.cqrs.usecase.query.Projection;

import java.util.Optional;

public interface ProductReadOnlyProjection extends Projection<ProductReadOnlyProjectionInput, Optional<ProductReadOnly>> {
}
