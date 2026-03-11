public class FT_InboundEmailProcessingQueueable implements Queueable, Database.AllowsCallouts {
    private final List<Id> emailMessageIds;

    public FT_InboundEmailProcessingQueueable(List<Id> emailMessageIds) {
        this.emailMessageIds = emailMessageIds == null ? new List<Id>() : emailMessageIds.deepClone();
    }

    public void execute(QueueableContext context) {
        if (emailMessageIds.isEmpty()) {
            return;
        }
        new FT_InboundEmailOrchestrator().processEmailMessages(new Set<Id>(emailMessageIds));
    }
}
