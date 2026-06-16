package tw.teddysoft.aiscrum.product.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.aiscrum.product.adapter.out.persistence.inmemory.InMemoryProductRepository;
import tw.teddysoft.aiscrum.product.adapter.out.projection.inmemory.InMemoryProductDtoProjection;
import tw.teddysoft.aiscrum.product.usecase.CreateProductService;
import tw.teddysoft.aiscrum.product.usecase.CreateProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.GetProductService;
import tw.teddysoft.aiscrum.product.usecase.GetProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.port.ProductDtoProjection;
import tw.teddysoft.aiscrum.product.usecase.port.ProductMapper;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

@Configuration
@Profile({"inmemory", "test-inmemory"})
public class ProductUseCaseConfig {

    @Bean
    public ProductRepository productRepository() {
        return new InMemoryProductRepository();
    }

    @Bean
    public ProductMapper productMapper() {
        return new ProductMapper();
    }

    @Bean
    public ProductDtoProjection productDtoProjection(ProductRepository productRepository, ProductMapper productMapper) {
        return new InMemoryProductDtoProjection(productRepository, productMapper);
    }

    @Bean
    public CreateProductUseCase createProductUseCase(ProductRepository productRepository) {
        return new CreateProductService(productRepository);
    }

    @Bean
    public GetProductUseCase getProductUseCase(ProductDtoProjection productDtoProjection) {
        return new GetProductService(productDtoProjection);
    }
}
