package tw.teddysoft.aiscrum.product.entity;

import tw.teddysoft.ezddd.entity.Entity;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public class ProductGoal implements Entity<ProductGoalId> {

    private final ProductGoalId id;
    private final String title;
    private final String description;
    private final List<GoalMetric> metrics;
    private final Instant definedAt;
    private Instant revisedAt;
    private ProductGoalState state;

    public ProductGoal(
            ProductGoalId id,
            String title,
            String description,
            List<GoalMetric> metrics,
            Instant definedAt,
            Instant revisedAt,
            ProductGoalState state) {
        this.id = Objects.requireNonNull(id, "ProductGoal id cannot be null");
        this.title = Objects.requireNonNull(title, "ProductGoal title cannot be null");
        this.description = Objects.requireNonNull(description, "ProductGoal description cannot be null");
        this.metrics = List.copyOf(Objects.requireNonNull(metrics, "ProductGoal metrics cannot be null"));
        this.definedAt = Objects.requireNonNull(definedAt, "ProductGoal definedAt cannot be null");
        this.revisedAt = revisedAt;
        this.state = Objects.requireNonNull(state, "ProductGoal state cannot be null");
    }

    @Override
    public ProductGoalId getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public List<GoalMetric> getMetrics() {
        return metrics;
    }

    public Instant getDefinedAt() {
        return definedAt;
    }

    public Instant getRevisedAt() {
        return revisedAt;
    }

    public ProductGoalState getState() {
        return state;
    }
}
