@IsTest
private class FT_CaseEmailWorkspaceControllerTest {
    @IsTest
    static void returnsCaseUiViewFromController() {
        FT_TestSupport.resetTestState();
        FT_ResendConfigService.setOverride(FT_TestSupport.buildTestConfig());
        Case supportCase = FT_TestSupport.createCaseRecord();
        FT_TestSupport.createInboundEmail(supportCase.Id, 'Please resend', 'Please resend my confirmation email.');
        FT_InboundEmailOrchestrator.mockAgentResponse = '{"summary":"UI summary","historySummary":"UI history","detectedIntent":"NONE","confidenceScore":0.60,"requiresManualReview":false}';

        FT_InboundEmailOrchestrator.CaseUiView view = FT_CaseEmailWorkspaceController.getCaseUiView(supportCase.Id);

        System.assertEquals('UI summary', view.summaryResult.summary);
        System.assertEquals('NO_ACTION', view.status);
    }

    @IsTest
    static void sendAllReturnsProviderResult() {
        FT_TestSupport.resetTestState();
        FT_ResendConfigService.setOverride(FT_TestSupport.buildTestConfig());
        Test.setMock(HttpCalloutMock.class, new FT_TestSupport.SuccessHttpCalloutMock());

        Case supportCase = FT_TestSupport.createCaseRecord();
        FT_TestSupport.createInboundEmail(supportCase.Id, 'Send all', 'Send all now.');

        FT_InboundEmailOrchestrator.ActionResult result = FT_CaseEmailWorkspaceController.sendAll(supportCase.Id);

        System.assertEquals(true, result.success);
        System.assertEquals('https://example.cloudpage.co/resend/abc123', result.cloudPageUrl);
    }
}
