trigger FT_EmailMessageTrigger on EmailMessage (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        FT_EmailMessageTriggerHandler.handleAfterInsert(Trigger.new);
    }
}
