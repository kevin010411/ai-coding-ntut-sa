package tw.teddysoft.aiscrum.product.entity;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public class ProductGoal {

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
        this.id = Objects.requireNonNull(id);
        this.title = Objects.requireNonNull(title);
        this.description = description;
        this.metrics = List.copyOf(Objects.requireNonNull(metrics));
        this.definedAt = Objects.requireNonNull(definedAt);
        this.revisedAt = revisedAt;
        this.state = Objects.requireNonNull(state);
    }

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
        return List.copyOf(metrics);
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
