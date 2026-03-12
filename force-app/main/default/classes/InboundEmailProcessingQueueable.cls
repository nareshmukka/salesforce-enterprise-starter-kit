/**
 * Description: Executes inbound EmailMessage processing asynchronously so downstream callouts are allowed.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class InboundEmailProcessingQueueable implements Queueable, Database.AllowsCallouts {
    private final List<Id> emailMessageIds;

    /**
     * Description: Creates the queueable job with the EmailMessage ids to process.
     * @param emailMessageIds Supported inbound EmailMessage ids.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public InboundEmailProcessingQueueable(List<Id> emailMessageIds) {
        this.emailMessageIds = emailMessageIds == null ? new List<Id>() : emailMessageIds.deepClone();
    }

    /**
     * Description: Runs async orchestration for the queued EmailMessage ids.
     * @param context Queueable execution context.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public void execute(QueueableContext context) {
        if (emailMessageIds.isEmpty()) {
            return;
        }
        new InboundEmailOrchestrator().processEmailMessages(new Set<Id>(emailMessageIds));
    }
}
