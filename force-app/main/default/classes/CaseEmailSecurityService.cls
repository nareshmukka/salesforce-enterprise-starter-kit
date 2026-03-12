/**
 * Description: Enforces CRUD and field-level access for case email workspace operations.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public inherited sharing class CaseEmailSecurityService {
    /**
     * Description: Validates read access to the Case fields used by the workspace.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static void assertCaseReadAccess() {
        if (!Schema.SObjectType.Case.isAccessible() ||
            !Schema.SObjectType.Case.fields.CaseNumber.isAccessible() ||
            !Schema.SObjectType.Case.fields.Latest_CloudPage_URL__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to case resend data.');
        }
    }

    /**
     * Description: Validates update access to the Case CloudPage URL field.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static void assertCaseUpdateAccess() {
        if (!Schema.SObjectType.Case.isUpdateable() ||
            !Schema.SObjectType.Case.fields.Latest_CloudPage_URL__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update the CloudPage URL.');
        }
    }

    /**
     * Description: Validates read access to EmailMessage records.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static void assertEmailMessageReadAccess() {
        if (!Schema.SObjectType.EmailMessage.isAccessible()) {
            throw new AuraHandledException('You do not have access to related email messages.');
        }
    }
}
