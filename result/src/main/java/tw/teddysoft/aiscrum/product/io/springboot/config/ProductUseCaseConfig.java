package tw.teddysoft.aiscrum.product.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import tw.teddysoft.aiscrum.product.adapter.out.persistence.inmemory.InMemoryProductRepository;
import tw.teddysoft.aiscrum.product.usecase.CreateProductService;
import tw.teddysoft.aiscrum.product.usecase.CreateProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.GetProductService;
import tw.teddysoft.aiscrum.product.usecase.GetProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

@Configuration
@Profile({"inmemory", "test-inmemory"})
public class ProductUseCaseConfig {

    @Bean
    public ProductRepository productRepository() {
        return new InMemoryProductRepository();
    }

    @Bean
    public CreateProductUseCase createProductUseCase(ProductRepository productRepository) {
        return new CreateProductService(productRepository);
    }

    @Bean
    public GetProductUseCase getProductUseCase(ProductRepository productRepository) {
        return new GetProductService(productRepository);
    }
}
