package tw.teddysoft.aiscrum.product.entity;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public class ProductGoalReadOnly implements ProductGoalReadable {

    private final ProductGoalReadable goal;

    private ProductGoalReadOnly(ProductGoalReadable goal) {
        this.goal = Objects.requireNonNull(goal);
    }

    public static ProductGoalReadOnly from(ProductGoalReadable goal) {
        if (goal == null) {
            return null;
        }
        if (goal instanceof ProductGoalReadOnly readOnly) {
            return readOnly;
        }
        return new ProductGoalReadOnly(goal);
    }

    @Override
    public ProductGoalId getId() {
        return goal.getId();
    }

    @Override
    public String getTitle() {
        return goal.getTitle();
    }

    @Override
    public String getDescription() {
        return goal.getDescription();
    }

    @Override
    public List<GoalMetric> getMetrics() {
        return List.copyOf(goal.getMetrics());
    }

    @Override
    public Instant getDefinedAt() {
        return goal.getDefinedAt();
    }

    @Override
    public Instant getRevisedAt() {
        return goal.getRevisedAt();
    }

    @Override
    public ProductGoalState getState() {
        return goal.getState();
    }
}
