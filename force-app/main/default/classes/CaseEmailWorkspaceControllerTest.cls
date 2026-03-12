@IsTest
/**
 * Description: Verifies Lightning controller responses for workspace load and Send All actions.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
private class CaseEmailWorkspaceControllerTest {
    @IsTest
    static void getCaseUiViewReturnsSummaryAndIntent() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"UI summary","category":"Resend Request","intent":"RESEND","confirmationNumber":"ABC12345","newEmailAddress":"updated@example.com","confidence":0.96}';

        Case supportCase = CaseEmailTestSupport.createCaseRecord();
        CaseEmailTestSupport.createInboundEmail(supportCase.Id, 'Need resend', 'Please resend to updated@example.com. Confirmation ABC12345');

        InboundEmailOrchestrator.CaseUiView view = CaseEmailWorkspaceController.getCaseUiView(supportCase.Id);

        System.assertEquals('UI summary', view.agentOutput.summary);
        System.assertEquals('RESEND', view.agentOutput.intent);
        System.assertEquals('updated@example.com', view.agentOutput.newEmailAddress);
    }

    @IsTest
    static void sendAllReturnsCloudPageUrl() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"Send all summary","category":"Resend Request","intent":"RESEND","confirmationNumber":"ABC12345","newEmailAddress":null,"confidence":0.94}';
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());

        Case supportCase = CaseEmailTestSupport.createCaseRecord();
        CaseEmailTestSupport.createInboundEmail(supportCase.Id, 'Send all', 'Send all now');

        InboundEmailOrchestrator.ActionResult result = CaseEmailWorkspaceController.sendAll(supportCase.Id);

        System.assertEquals(true, result.success);
        System.assertEquals('https://example.cloudpage.co/resend/abc123', result.cloudPageUrl);
    }
}
