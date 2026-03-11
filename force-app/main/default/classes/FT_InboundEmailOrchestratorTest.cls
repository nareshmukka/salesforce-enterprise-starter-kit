@IsTest
private class FT_InboundEmailOrchestratorTest {
    @IsTest
    static void returnsPendingInputWhenConfirmationIsMissing() {
        FT_TestSupport.resetTestState();
        FT_ResendConfigService.setOverride(FT_TestSupport.buildTestConfig());
        Case supportCase = FT_TestSupport.createCaseRecord();
        FT_TestSupport.createInboundEmail(supportCase.Id, 'Please resend', 'Please resend my confirmation email.');
        FT_InboundEmailOrchestrator.mockAgentResponse = '{"summary":"Customer asked for resend","historySummary":"Two emails reviewed","detectedIntent":"RESEND","confidenceScore":0.88,"requiresManualReview":false}';

        FT_InboundEmailOrchestrator.CaseUiView view = new FT_InboundEmailOrchestrator().getCaseUiView(supportCase.Id);

        System.assertEquals('PENDING_INPUT', view.status);
        System.assertEquals('Customer asked for resend', view.summaryResult.summary);
    }

    @IsTest
    static void updatesCaseWhenResendRuns() {
        FT_TestSupport.resetTestState();
        FT_ResendConfigService.setOverride(FT_TestSupport.buildTestConfig());
        Test.setMock(HttpCalloutMock.class, new FT_TestSupport.SuccessHttpCalloutMock());

        Case supportCase = FT_TestSupport.createCaseRecord();
        EmailMessage emailMessage = FT_TestSupport.createInboundEmail(
            supportCase.Id,
            'Please resend',
            'Please resend. Confirmation number: ABC12345'
        );
        FT_InboundEmailOrchestrator.mockAgentResponse = '{"summary":"Resend confirmed","historySummary":"One email reviewed","detectedIntent":"RESEND","candidateConfirmationNumber":"ABC12345","confidenceScore":0.95,"requiresManualReview":false}';

        Test.startTest();
        new FT_InboundEmailOrchestrator().processEmailMessages(new Set<Id>{ emailMessage.Id });
        Test.stopTest();

        Case refreshed = [SELECT FT_Latest_CloudPage_URL__c FROM Case WHERE Id = :supportCase.Id];
        System.assertEquals('https://example.cloudpage.co/resend/abc123', refreshed.FT_Latest_CloudPage_URL__c);
    }
}
