package tw.teddysoft.example.plan.entity;

import tw.teddysoft.example.tag.entity.TagId;
import tw.teddysoft.ezddd.entity.DomainEventTypeMapper;
import tw.teddysoft.ezddd.entity.InternalDomainEvent;

import java.time.Instant;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

// @authority: domain_event_mapper_key | source: patterns/domain/domain-event.md
// @authority: mapping_type_prefix_position | source: patterns/domain/domain-event.md
public sealed interface PlanEvents extends InternalDomainEvent {

    PlanId planId();

    // source() 回傳 aggregate instance ID，DRY：interface 層級定義一次，所有 record 自動繼承
    @Override
    default String source() {
        return planId().value();
    }

    // Inline mapper — MAPPING_TYPE_PREFIX keys (authority: domain-event.md)
    String MAPPING_TYPE_PREFIX = "PlanEvents$";

    record PlanCreated(
            PlanId planId,
            String name,
            String userId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents, InternalDomainEvent.ConstructionEvent {
        public PlanCreated {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(name);
            Objects.requireNonNull(userId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record PlanRenamed(
            PlanId planId,
            String newName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public PlanRenamed {
            Objects.requireNonNull(planId);
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

    record PlanDeleted(
            PlanId planId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents, InternalDomainEvent.DestructionEvent {
        public PlanDeleted {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record ProjectCreated(
            PlanId planId,
            ProjectId projectId,
            ProjectName projectName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public ProjectCreated {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(projectName);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record ProjectDeleted(
            PlanId planId,
            ProjectId projectId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public ProjectDeleted {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskCreated(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            String taskName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskCreated {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(taskName);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskChecked(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskChecked {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskUnchecked(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskUnchecked {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskDeleted(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskDeleted {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskDeadlineSet(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            String deadline,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskDeadlineSet {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            // deadline can be null (to remove deadline)
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TaskRenamed(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            String newName,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TaskRenamed {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
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

    record TagAssigned(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            TagId tagId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TagAssigned {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(tagId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    record TagUnassigned(
            PlanId planId,
            ProjectId projectId,
            TaskId taskId,
            TagId tagId,
            Map<String, String> metadata,
            UUID id,
            Instant occurredOn
    ) implements PlanEvents {
        public TagUnassigned {
            Objects.requireNonNull(planId);
            Objects.requireNonNull(projectId);
            Objects.requireNonNull(taskId);
            Objects.requireNonNull(tagId);
            Objects.requireNonNull(metadata);
            Objects.requireNonNull(id);
            Objects.requireNonNull(occurredOn);
        }

        @Override
        public Map<String, String> metadata() {
            return metadata;
        }
    }

    static DomainEventTypeMapper mapper() {
        DomainEventTypeMapper mapper = DomainEventTypeMapper.create();
        mapper.put(MAPPING_TYPE_PREFIX + "PlanCreated", PlanCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "PlanRenamed", PlanRenamed.class);
        mapper.put(MAPPING_TYPE_PREFIX + "PlanDeleted", PlanDeleted.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProjectCreated", ProjectCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "ProjectDeleted", ProjectDeleted.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskCreated", TaskCreated.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskChecked", TaskChecked.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskUnchecked", TaskUnchecked.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskDeleted", TaskDeleted.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskDeadlineSet", TaskDeadlineSet.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TaskRenamed", TaskRenamed.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TagAssigned", TagAssigned.class);
        mapper.put(MAPPING_TYPE_PREFIX + "TagUnassigned", TagUnassigned.class);
        return mapper;
    }
}