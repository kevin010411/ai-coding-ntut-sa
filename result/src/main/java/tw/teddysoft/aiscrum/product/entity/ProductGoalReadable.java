package tw.teddysoft.aiscrum.product.entity;

import java.time.Instant;
import java.util.List;

public interface ProductGoalReadable {

    ProductGoalId getId();

    String getTitle();

    String getDescription();

    List<GoalMetric> getMetrics();

    Instant getDefinedAt();

    Instant getRevisedAt();

    ProductGoalState getState();
}
