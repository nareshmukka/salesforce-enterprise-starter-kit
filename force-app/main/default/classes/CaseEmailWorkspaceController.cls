/**
 * Description: Exposes the inbound email workspace to Lightning components with explicit security checks.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public inherited sharing class CaseEmailWorkspaceController {
    /**
     * Description: Returns the workspace view for a Case page.
     * @param caseId Case id displayed in the Lightning workspace.
     * @return CaseUiView Workspace data for the UI.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @AuraEnabled
    public static InboundEmailOrchestrator.CaseUiView getCaseUiView(Id caseId) {
        CaseEmailSecurityService.assertCaseReadAccess();
        CaseEmailSecurityService.assertEmailMessageReadAccess();
        return new InboundEmailOrchestrator().getCaseUiView(caseId);
    }

    /**
     * Description: Executes the Send All action from the Lightning workspace.
     * @param caseId Case id selected in the UI.
     * @return ActionResult Send All result.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @AuraEnabled
    public static InboundEmailOrchestrator.ActionResult sendAll(Id caseId) {
        CaseEmailSecurityService.assertCaseReadAccess();
        CaseEmailSecurityService.assertCaseUpdateAccess();
        CaseEmailSecurityService.assertEmailMessageReadAccess();
        return new InboundEmailOrchestrator().sendAll(caseId);
    }

    /**
     * Description: Reprocesses the latest inbound email for a Case.
     * @param caseId Case id to reprocess.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @AuraEnabled
    public static void reprocessLatest(Id caseId) {
        CaseEmailSecurityService.assertCaseReadAccess();
        CaseEmailSecurityService.assertEmailMessageReadAccess();
        new InboundEmailOrchestrator().reprocessLatest(caseId);
    }
}
