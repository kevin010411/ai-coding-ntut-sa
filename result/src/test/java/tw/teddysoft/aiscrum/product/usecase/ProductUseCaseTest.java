package tw.teddysoft.aiscrum.product.usecase;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import tw.teddysoft.aiscrum.product.entity.ProductLifecycleState;
import tw.teddysoft.aiscrum.product.entity.ProductName;
import tw.teddysoft.ezddd.cqrs.usecase.CqrsOutput;
import tw.teddysoft.ezddd.usecase.port.in.interactor.ExitCode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest(properties = "spring.profiles.active=test-inmemory")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class ProductUseCaseTest {

    @Autowired
    private CreateProductUseCase createProductUseCase;

    @Autowired
    private GetProductUseCase getProductUseCase;

    @Autowired
    private RenameProductUseCase renameProductUseCase;

    @Test
    void should_create_product_successfully() {
        CqrsOutput<?> output = createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        assertEquals(ExitCode.SUCCESS, output.getExitCode());
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

        assertEquals(ExitCode.SUCCESS, output.getExitCode());
        assertNotNull(output.getReadonlyProduct());
        assertEquals("product-123", output.getReadonlyProduct().getId().value());
        assertEquals("AI Scrum Assistant", output.getReadonlyProduct().getName().value());
        assertEquals(ProductLifecycleState.DRAFT, output.getReadonlyProduct().getState());
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

        assertThrows(UnsupportedOperationException.class,
                () -> output.getReadonlyProduct().rename(ProductName.valueOf("Blocked"), "user-456"));
    }

    @Test
    void should_rename_product_successfully() {
        createProductUseCase.execute(
                CreateProductUseCase.CreateProductInput.create(
                        "product-123",
                        "AI Scrum Assistant",
                        "user-456"));

        CqrsOutput<?> renameOutput = renameProductUseCase.execute(
                RenameProductUseCase.RenameProductInput.create(
                        "product-123",
                        "AI Scrum Coach",
                        "user-456"));

        GetProductUseCase.GetProductOutput output = getProductUseCase.execute(
                GetProductUseCase.GetProductInput.create("product-123"));

        assertEquals(ExitCode.SUCCESS, renameOutput.getExitCode());
        assertEquals("AI Scrum Coach", output.getReadonlyProduct().getName().value());
    }

    @Test
    void should_return_failure_when_product_not_found() {
        GetProductUseCase.GetProductOutput output = getProductUseCase.execute(
                GetProductUseCase.GetProductInput.create("missing-product"));

        assertEquals(ExitCode.FAILURE, output.getExitCode());
    }

    @Test
    void should_return_failure_when_renaming_missing_product() {
        CqrsOutput<?> output = renameProductUseCase.execute(
                RenameProductUseCase.RenameProductInput.create(
                        "missing-product",
                        "AI Scrum Coach",
                        "user-456"));

        assertEquals(ExitCode.FAILURE, output.getExitCode());
    }
}
