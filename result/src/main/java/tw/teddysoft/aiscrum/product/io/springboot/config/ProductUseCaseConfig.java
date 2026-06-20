package tw.teddysoft.aiscrum.product.io.springboot.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tw.teddysoft.aiscrum.product.adapter.out.persistence.inmemory.InMemoryProductRepository;
import tw.teddysoft.aiscrum.product.usecase.CreateProductService;
import tw.teddysoft.aiscrum.product.usecase.CreateProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.GetProductService;
import tw.teddysoft.aiscrum.product.usecase.GetProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.RenameProductService;
import tw.teddysoft.aiscrum.product.usecase.RenameProductUseCase;
import tw.teddysoft.aiscrum.product.usecase.port.ProductRepository;

@Configuration
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

    @Bean
    public RenameProductUseCase renameProductUseCase(ProductRepository productRepository) {
        return new RenameProductService(productRepository);
    }
}
