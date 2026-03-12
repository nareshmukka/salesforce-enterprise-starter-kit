/**
 * Description: Filters supported inbound EmailMessage records and hands them off for async processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class EmailMessageTriggerHandler {
    private static Set<Id> queuedEmailIds = new Set<Id>();

    /**
     * Description: Handles after insert EmailMessage trigger processing.
     * @param newRecords Newly inserted EmailMessage records.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static void handleAfterInsert(List<EmailMessage> newRecords) {
        ResendConfiguration.Config config = ResendConfiguration.getConfig();
        Set<Id> emailMessageIds = new Set<Id>();

        for (EmailMessage record : newRecords) {
            if (record == null ||
                record.Id == null ||
                queuedEmailIds.contains(record.Id) ||
                record.Incoming != true ||
                record.ParentId == null ||
                record.ParentId.getSObjectType() != Case.SObjectType) {
                continue;
            }

            if (String.isBlank(config.supportedInboundAddressRegex) ||
                String.isBlank(record.ToAddress) ||
                Pattern.compile(config.supportedInboundAddressRegex).matcher(record.ToAddress).matches()) {
                emailMessageIds.add(record.Id);
            }
        }

        if (emailMessageIds.isEmpty()) {
            return;
        }

        queuedEmailIds.addAll(emailMessageIds);
        System.enqueueJob(new InboundEmailProcessingQueueable(new List<Id>(emailMessageIds)));
    }

    /**
     * Description: Resets the in-transaction queue guard for tests.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    static void reset() {
        queuedEmailIds.clear();
    }
}
