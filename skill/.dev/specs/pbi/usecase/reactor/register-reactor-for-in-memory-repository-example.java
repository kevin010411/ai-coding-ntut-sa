// 範例：在 Spring Boot 應用程式中註冊 Reactor 以處理 Domain Events
// 適用於使用 In-Memory Repository 的情境
//
// **ezapp 2.0.0 注意**：InMemory 模式現在使用框架提供的類別：
// - InMemoryOrmDb + InMemoryOrmClient + OutboxRepository
// - InMemoryMessageDb + InMemoryMessageDbClient
// 參考：.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/ProductInMemoryRepositoryConfig.java

package tw.teddysoft.aiscrum.io.springboot;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import tw.teddysoft.aiscrum.pbi.usecase.reactor.NotifyProductBacklogItemWhenSprintStartedReactor;
import tw.teddysoft.ezddd.entity.DomainEvent;
import tw.teddysoft.ezddd.usecase.port.inout.messaging.MessageBus;

import javax.annotation.PostConstruct;
import javax.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@SpringBootApplication(scanBasePackages = "tw.teddysoft.aiscrum")
@ComponentScan(basePackages = "tw.teddysoft.aiscrum")
public class AiScrumApp {
    
    private static int appInstanceCount = 0;
    private final int appInstanceId;
    private final ExecutorService executor;
    private final MessageBus<DomainEvent> messageBus;
    private final NotifyProductBacklogItemWhenSprintStartedReactor notifyPbiReactor;

    @Autowired
    public AiScrumApp(MessageBus<DomainEvent> messageBus,
                      NotifyProductBacklogItemWhenSprintStartedReactor notifyPbiReactor) {
        this.appInstanceId = ++appInstanceCount;
        System.out.println("===> Creating AiScrumApp instance #" + appInstanceId);

        this.messageBus = messageBus;
        this.notifyPbiReactor = notifyPbiReactor;
        
        // Create executor service for async message processing
        // 使用 Virtual Thread 以提供更好的並發性能（Java 21+）
        executor = Executors.newVirtualThreadPerTaskExecutor();
        
        // 如果是 Java 21 以下版本，可以使用：
        // executor = Executors.newFixedThreadPool(4);
    }
    
    @PostConstruct
    public void init() {
        // 註冊 Reactor 到 MessageBus
        // 這樣當 Domain Event 發布時，Reactor 會自動被觸發
        if (notifyPbiReactor != null) {
            System.out.println("===> Registering NotifyProductBacklogItemWhenSprintStartedReactor");
            System.out.println("===> Note: Reactor is configured via Spring beans and MessageBus in UseCaseConfiguration");
            
            // 關鍵步驟：將 Reactor 註冊到 MessageBus
            messageBus.register(notifyPbiReactor);
            
            // 注意：ezapp 2.0.0 使用 InMemoryMessageBroker 替代 BlockingMessageBus
            // InMemory 模式下事件處理流程透過框架自動管理
            
            // 如果使用非同步的 MessageBus 實作，可能需要：
            // executor.execute(messageBus);
        }
        
        System.out.println("===> AiScrumApp initialized with ExecutorService for async processing");
        System.out.println("===> Reactor will be triggered automatically when SprintStarted events are published");
    }
    
    @PreDestroy
    public void cleanup() {
        System.out.println("===> Shutting down AiScrumApp...");
        
        // 優雅關閉 ExecutorService
        if (executor != null) {
            executor.shutdown();
            try {
                // 等待現有任務完成，最多等待 5 秒
                if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                    // 如果超時，強制關閉
                    executor.shutdownNow();
                }
            } catch (InterruptedException e) {
                executor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
    }
    
    public static void main(String[] args) {
        SpringApplication.run(AiScrumApp.class, args);
    }
}

// ============================================================
// 重要說明
// ============================================================

/*
1. MessageBus 配置 (ezapp 2.0.0)
   - ezapp 2.0.0 使用 InMemoryMessageBroker 替代 BlockingMessageBus
   - InMemory 模式使用 OutboxRepository + InMemoryOrmClient + InMemoryMessageDbClient
   - 事件透過 OutboxRepository 自動儲存和發布

2. Reactor 註冊時機
   - 使用 @PostConstruct 確保在 Spring 容器初始化完成後註冊
   - 這確保所有依賴都已正確注入

3. Reactor 介面定義
   - 必須繼承 Reactor<DomainEvent>（注意不是 DomainEventData）
   - execute 方法簽名：void execute(DomainEvent event)

4. ExecutorService 用途
   - 提供非同步處理能力
   - 使用 Virtual Thread（Java 21+）可提供更好的並發性能
   - 在應用程式關閉時需要優雅關閉

5. 典型的配置 (ezapp 2.0.0)：

   // InMemoryRepositoryConfig.java - Repository 配置
   @Configuration
   @Profile({"inmemory", "test-inmemory"})
   public class InMemoryRepositoryConfig {

       @Bean
       public InMemoryMessageDb inMemoryMessageDb() {
           return new InMemoryMessageDb();
       }

       @Bean
       public InMemoryMessageDbClient inMemoryMessageDbClient(InMemoryMessageDb messageDb) {
           return new InMemoryMessageDbClient(messageDb);
       }

       // 每個 Aggregate 的 Repository 配置...
       // 參考：.ai/tech-stacks/java-ezddd-spring/examples/spring/aggregate-specific/ProductInMemoryRepositoryConfig.java
   }

   // UseCaseConfiguration.java - Use Case 和 Reactor 配置
   @Configuration
   public class UseCaseConfiguration {

       @Bean
       public NotifyProductBacklogItemWhenSprintStartedReactor notifyPbiReactor(
               FindPbisBySprintIdInquiry inquiry,
               Repository<ProductBacklogItem, PbiId> repository) {
           return new NotifyProductBacklogItemWhenSprintStartedService(inquiry, repository);
       }
   }

6. 事件流程：
   a. Use Case 執行時發布 Domain Event
   b. Event 被發送到 MessageBus
   c. MessageBus 通知所有註冊的 Reactor
   d. Reactor 的 execute 方法被調用處理事件

7. 注意事項：
   - 確保 Reactor 是 Spring Bean（透過 @Bean 或 @Component）
   - 避免重複註冊同一個 Reactor
   - 處理事件時要有適當的錯誤處理機制
   - 考慮事件處理的順序和一致性
*/
