package tw.teddysoft.aiscrum.product.adapter.out.projection.inmemory;

import tw.teddysoft.aiscrum.product.entity.ProductId;
import tw.teddysoft.aiscrum.product.usecase.port.ProductDto;
import tw.teddysoft.aiscrum.product.usecase.port.ProductDtoProjection;
import tw.teddysoft.aiscrum.product.usecase.port.ProductDtoProjectionInput;
import tw.teddysoft.aiscrum.product.usecase.port.ProductMapper;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

import java.util.Optional;

public class InMemoryProductDtoProjection implements ProductDtoProjection {

    private final ProductRepository productRepository;
    private final ProductMapper productMapper;

    public InMemoryProductDtoProjection(ProductRepository productRepository, ProductMapper productMapper) {
        this.productRepository = productRepository;
        this.productMapper = productMapper;
    }

    @Override
    public Optional<ProductDto> query(ProductDtoProjectionInput input) {
        return productRepository.findById(ProductId.valueOf(input.productId()))
                .map(productMapper::toDto);
    }
}
