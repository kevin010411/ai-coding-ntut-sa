package tw.teddysoft.aiscrum.product.usecase;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.aiscrum.product.entity.ProductLifecycleState;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;

import java.util.NoSuchElementException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class ProductUseCaseTest {

    @Autowired
    private CreateProductUseCase createProductUseCase;

    @Autowired
    private GetProductUseCase getProductUseCase;

    @Test
    void should_create_product_successfully() {
        CqrsOutput<?> output = createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        assertNotNull(output);
    }

    @Test
    void should_get_product_as_dto_successfully() {
        createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        GetProductUseCase.GetProductOutput output = getProductUseCase.execute(
                GetProductUseCase.GetProductInput.create("product-123"));

        assertNotNull(output);
        assertNotNull(output.getProduct());
        assertEquals("product-123", output.getProduct().id().value());
        assertEquals("AI Scrum Assistant", output.getProduct().name().value());
        assertEquals(ProductLifecycleState.DRAFT, output.getProduct().state());
    }

    @Test
    void should_return_failure_when_product_not_found() {
        assertThrows(
                NoSuchElementException.class,
                () -> getProductUseCase.execute(GetProductUseCase.GetProductInput.create("missing-product")));
    }
}
