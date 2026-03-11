public inherited sharing class FT_SecurityService {
    public static void assertCaseReadAccess() {
        if (!Schema.SObjectType.Case.isAccessible() ||
            !Schema.SObjectType.Case.fields.CaseNumber.isAccessible() ||
            !Schema.SObjectType.Case.fields.FT_Latest_CloudPage_URL__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to case resend data.');
        }
    }

    public static void assertCaseUpdateAccess() {
        if (!Schema.SObjectType.Case.isUpdateable() ||
            !Schema.SObjectType.Case.fields.FT_Latest_CloudPage_URL__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update the CloudPage URL.');
        }
    }

    public static void assertEmailMessageReadAccess() {
        if (!Schema.SObjectType.EmailMessage.isAccessible()) {
            throw new AuraHandledException('You do not have access to related email messages.');
        }
    }
}
