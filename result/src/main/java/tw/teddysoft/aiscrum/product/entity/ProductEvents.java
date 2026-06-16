package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

public sealed interface ProductEvents extends InternalDomainEvent {

    String MAPPING_TYPE_PREFIX = "tw.teddysoft.aiscrum.product.";

    ProductId productId();

    @Override
    default String source() {
        return productId().value();
    }

    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        return mapper;
    }

    record ProductCreated(
            ProductId productId,
            ProductName name,
            ProductGoal goal,
            String note,
            String extension,
            ProductLifecycleState state,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ProductEvents, InternalDomainEvent.ConstructionEvent {

        public ProductCreated {
            Objects.requireNonNull(productId, "productId cannot be null");
            Objects.requireNonNull(name, "name cannot be null");
            Objects.requireNonNull(state, "state cannot be null");
            Objects.requireNonNull(metadata, "metadata cannot be null");
            Objects.requireNonNull(id, "id cannot be null");
            Objects.requireNonNull(occurredOn, "occurredOn cannot be null");
        }
    }
}
