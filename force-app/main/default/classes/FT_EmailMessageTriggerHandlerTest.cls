@IsTest
private class FT_EmailMessageTriggerHandlerTest {
    @IsTest
    static void triggerQueuesAsyncProcessingAndProjectsCloudPageUrl() {
        FT_TestSupport.resetTestState();
        FT_ResendConfigService.setOverride(FT_TestSupport.buildTestConfig());
        Test.setMock(HttpCalloutMock.class, new FT_TestSupport.SuccessHttpCalloutMock());
        Case supportCase = FT_TestSupport.createCaseRecord();
        FT_InboundEmailOrchestrator.mockAgentResponse = '{"summary":"Trigger path","historySummary":"One email","detectedIntent":"RESEND","candidateConfirmationNumber":"ABC12345","confidenceScore":0.92,"requiresManualReview":false}';

        Test.startTest();
        FT_TestSupport.createInboundEmail(supportCase.Id, 'Please resend', 'Please resend. Confirmation number: ABC12345');
        Test.stopTest();

        Case refreshed = [SELECT FT_Latest_CloudPage_URL__c FROM Case WHERE Id = :supportCase.Id];
        System.assertEquals('https://example.cloudpage.co/resend/abc123', refreshed.FT_Latest_CloudPage_URL__c);
    }
}
