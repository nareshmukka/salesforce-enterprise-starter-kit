/**
 * Description: Filters supported inbound EmailMessage records and hands them off for async processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class EmailMessageTriggerHandler {
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
            if (!isSupportedInboundEmail(record, config)) {
                continue;
            }
            if (queuedEmailIds.contains(record.Id)) {
                continue;
            }
            emailMessageIds.add(record.Id);
        }

        if (emailMessageIds.isEmpty()) {
            return;
        }

        queuedEmailIds.addAll(emailMessageIds);
        System.enqueueJob(new InboundEmailProcessingQueueable(new List<Id>(emailMessageIds)));
    }

    /**
     * Description: Validates whether an EmailMessage should enter resend automation processing.
     * @param record Newly inserted EmailMessage.
     * @param config Active resend configuration.
     * @return Boolean True when the record is supported for processing.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private static Boolean isSupportedInboundEmail(EmailMessage record, ResendConfiguration.Config config) {
        if (record == null ||
            record.Id == null ||
            record.Incoming != true ||
            record.ParentId == null ||
            record.ParentId.getSObjectType() != Case.SObjectType) {
            return false;
        }

        if (String.isBlank(config.supportedInboundAddressRegex)) {
            return true;
        }

        if (String.isBlank(record.ToAddress)) {
            return false;
        }

        return Pattern.compile(config.supportedInboundAddressRegex).matcher(record.ToAddress).matches();
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