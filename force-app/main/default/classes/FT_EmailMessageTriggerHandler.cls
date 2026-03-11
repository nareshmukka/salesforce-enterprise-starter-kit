public class FT_EmailMessageTriggerHandler {
    private static Set<Id> queuedEmailIds = new Set<Id>();

    public static void handleAfterInsert(List<EmailMessage> newRecords) {
        FT_ResendConfigService.Config config = FT_ResendConfigService.getConfig();
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
        System.enqueueJob(new FT_InboundEmailProcessingQueueable(new List<Id>(emailMessageIds)));
    }

    @TestVisible
    static void reset() {
        queuedEmailIds.clear();
    }
}
