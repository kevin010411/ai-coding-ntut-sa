package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

public sealed interface ProductEvents extends InternalDomainEvent {

    ProductId productId();

    @Override
    default String source() {
        return productId().value();
    }

    String MAPPING_TYPE_PREFIX = "ProductEvents$";

    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "ProductCreated", ProductCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProductRenamed", ProductRenamed.class);
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
            Objects.requireNonNull(productId);
            Objects.requireNonNull(name);
            Objects.requireNonNull(state);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record ProductRenamed(
            ProductId productId,
            ProductName oldName,
            ProductName newName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements ProductEvents {

        public ProductRenamed {
            Objects.requireNonNull(productId);
            Objects.requireNonNull(oldName);
            Objects.requireNonNull(newName);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }
}
