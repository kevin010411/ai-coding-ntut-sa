package tw.teddysoft.aiscrum.product.usecase;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.aiscrum.product.entity.ProductLifecycleState;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;

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
        assertEquals("product-123", output.getId());
    }

    @Test
    void should_get_product_as_read_only_entity_successfully() {
        createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        GetProductUseCase.GetProductOutput output = getProductUseCase.execute(
                GetProductUseCase.GetProductInput.create("product-123"));

        assertNotNull(output);
        assertNotNull(output.getProduct());
        assertEquals("product-123", output.getProduct().getId().value());
        assertEquals("AI Scrum Assistant", output.getProduct().getName().value());
        assertEquals(ProductLifecycleState.DRAFT, output.getProduct().getState());
    }

    @Test
    void should_reject_mutation_on_read_only_product() {
        createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        GetProductUseCase.GetProductOutput output = getProductUseCase.execute(
                GetProductUseCase.GetProductInput.create("product-123"));

        assertThrows(UnsupportedOperationException.class, () -> output.getProduct().rejectMutation());
    }

    @Test
    void should_return_failure_when_product_not_found() {
        assertThrows(
                java.util.NoSuchElementException.class,
                () -> getProductUseCase.execute(GetProductUseCase.GetProductInput.create("missing-product")));
    }
}
