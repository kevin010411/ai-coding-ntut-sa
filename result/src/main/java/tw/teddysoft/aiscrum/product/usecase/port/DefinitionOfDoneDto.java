package tw.teddysoft.aiscrum.product.usecase.port;

import java.time.Instant;
import java.util.List;

public record DefinitionOfDoneDto(
        String name,
        List<String> criteria,
        String note,
        Instant definedAt
) {

    public DefinitionOfDoneDto {
        criteria = List.copyOf(criteria);
    }
}
