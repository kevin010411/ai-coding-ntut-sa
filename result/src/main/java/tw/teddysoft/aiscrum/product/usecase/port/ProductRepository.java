package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.aiscrum.product.entity.Product;
import tw.teddysoft.aiscrum.product.entity.ProductId;

import java.util.Optional;

public interface ProductRepository {

    void save(Product product);

    Optional<Product> findById(ProductId id);
}
