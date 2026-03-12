/**
 * Description: Starts inbound EmailMessage processing after new inbound case emails are created.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
trigger EmailMessageTrigger on EmailMessage (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        EmailMessageTriggerHandler.handleAfterInsert(Trigger.new);
    }
}