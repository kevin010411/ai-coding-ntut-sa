package tw.teddysoft.aiscrum.product.usecase.port;

import tw.teddysoft.aiscrum.product.entity.Product;

import java.util.Optional;

public class ProductMapper {

    public ProductDto toDto(Product product) {
        return new ProductDto(
                product.getId(),
                product.getName(),
                product.getGoal(),
                Optional.empty(),
                product.getNote(),
                product.getExtension(),
                product.getState());
    }
}
