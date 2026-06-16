package tw.teddysoft.aiscrum.product.entity;

public interface ProductReadable {

    ProductId getId();

    ProductName getName();

    ProductGoalReadable getGoal();

    String getNote();

    String getExtension();

    ProductLifecycleState getState();
}
