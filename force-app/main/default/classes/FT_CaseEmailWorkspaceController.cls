public inherited sharing class FT_CaseEmailWorkspaceController {
    @AuraEnabled
    public static FT_InboundEmailOrchestrator.CaseUiView getCaseUiView(Id caseId) {
        FT_SecurityService.assertCaseReadAccess();
        FT_SecurityService.assertEmailMessageReadAccess();
        return new FT_InboundEmailOrchestrator().getCaseUiView(caseId);
    }

    @AuraEnabled
    public static FT_InboundEmailOrchestrator.ActionResult sendAll(Id caseId) {
        FT_SecurityService.assertCaseReadAccess();
        FT_SecurityService.assertCaseUpdateAccess();
        FT_SecurityService.assertEmailMessageReadAccess();
        return new FT_InboundEmailOrchestrator().sendAll(caseId);
    }

    @AuraEnabled
    public static void reprocessLatest(Id caseId) {
        FT_SecurityService.assertCaseReadAccess();
        FT_SecurityService.assertEmailMessageReadAccess();
        new FT_InboundEmailOrchestrator().reprocessLatest(caseId);
    }
}
