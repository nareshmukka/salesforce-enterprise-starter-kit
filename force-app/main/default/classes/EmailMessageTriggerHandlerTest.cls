@IsTest
/**
 * Description: Verifies inbound EmailMessage trigger handling, filtering, and async processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
private class EmailMessageTriggerHandlerTest {
    @IsTest
    static void triggerQueuesAsyncProcessingAndProjectsCloudPageUrl() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"Trigger path","category":"Resend Request","intent":"RESEND","confirmationNumber":"ABC12345","newEmailAddress":null,"confidence":0.92}';
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());

        Case supportCase = CaseEmailTestSupport.createCaseRecord();

        Test.startTest();
        CaseEmailTestSupport.createInboundEmail(supportCase.Id, 'Please resend', 'Please resend. Confirmation number: ABC12345');
        Test.stopTest();

        Case refreshed = [SELECT Latest_CloudPage_URL__c FROM Case WHERE Id = :supportCase.Id];
        System.assertEquals('https://example.cloudpage.co/resend/abc123', refreshed.Latest_CloudPage_URL__c);
    }

    @IsTest
    static void handlerIgnoresNonInboundEmailMessages() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        Case supportCase = CaseEmailTestSupport.createCaseRecord();

        EmailMessage emailRecord = new EmailMessage(
            ParentId = supportCase.Id,
            Incoming = false,
            FromAddress = 'agent@example.com',
            ToAddress = 'customer@example.com',
            Subject = 'Outbound',
            TextBody = 'Outbound email',
            Status = '3'
        );

        Test.startTest();
        insert emailRecord;
        Test.stopTest();

        Case refreshed = [SELECT Latest_CloudPage_URL__c FROM Case WHERE Id = :supportCase.Id];
        System.assertEquals(null, refreshed.Latest_CloudPage_URL__c);
    }
}
