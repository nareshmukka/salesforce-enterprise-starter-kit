@IsTest
/**
 * Description: Verifies orchestrator JSON handling, endpoint selection, confirmation handling, and bulk processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
private class InboundEmailOrchestratorTest {
    @IsTest
    static void workspaceShowsAgentOutputAndPendingInputWhenConfirmationMissing() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"Customer needs resend","category":"Resend Request","intent":"RESEND","confirmationNumber":null,"newEmailAddress":"newmail@example.com","confidence":0.88}';
        Case supportCase = CaseEmailTestSupport.createCaseRecord();
        CaseEmailTestSupport.createInboundEmail(supportCase.Id, 'Need resend', 'Please resend to newmail@example.com');

        InboundEmailOrchestrator.CaseUiView view = new InboundEmailOrchestrator().getCaseUiView(supportCase.Id);

        System.assertEquals('PENDING_INPUT', view.status);
        System.assertEquals('Resend Request', view.agentOutput.category);
        System.assertEquals('newmail@example.com', view.agentOutput.newEmailAddress);
        System.assert(AgentIntegrationService.lastRequestJson.contains('"caseId"'));
    }

    @IsTest
    static void resendUsesNewEmailEndpointWhenNewEmailExists() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"Customer needs resend","category":"Resend Request","intent":"RESEND","confirmationNumber":"ABC12345","newEmailAddress":"updated@example.com","confidence":0.94}';
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());

        Case supportCase = CaseEmailTestSupport.createCaseRecord();
        EmailMessage emailMessage = CaseEmailTestSupport.createInboundEmail(
            supportCase.Id,
            'Need resend',
            'Please resend to updated@example.com. Confirmation number ABC12345'
        );

        Test.startTest();
        new InboundEmailOrchestrator().processEmailMessages(new Set<Id>{ emailMessage.Id });
        Test.stopTest();

        Case refreshed = [SELECT Latest_CloudPage_URL__c FROM Case WHERE Id = :supportCase.Id];
        System.assertEquals('https://example.cloudpage.co/resend/abc123', refreshed.Latest_CloudPage_URL__c);
        System.assert(AgentIntegrationService.lastRequestJson.contains('"updated@example.com"'));
    }

    @IsTest
    static void processesBulkInboundEmailsWithoutErrors() {
        CaseEmailTestSupport.resetTestState();
        ResendConfiguration.setOverride(CaseEmailTestSupport.buildTestConfig());
        AgentIntegrationService.mockResponseJson = '{"summary":"Bulk resend","category":"Resend Request","intent":"RESEND","confirmationNumber":"ABC12345","newEmailAddress":null,"confidence":0.91}';
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());

        List<Case> casesToInsert = new List<Case>();
        for (Integer index = 0; index < 5; index++) {
            casesToInsert.add(new Case(
                Origin = 'Email',
                Status = 'New',
                Subject = 'Inbound resend request ' + index,
                SuppliedEmail = 'customer' + index + '@example.com'
            ));
        }
        insert casesToInsert;

        List<EmailMessage> emails = new List<EmailMessage>();
        for (Case supportCase : casesToInsert) {
            emails.add(new EmailMessage(
                ParentId = supportCase.Id,
                Incoming = true,
                FromAddress = supportCase.SuppliedEmail,
                ToAddress = 'support@example.com',
                Subject = 'Bulk resend',
                TextBody = 'Please resend. Confirmation number ABC12345',
                Status = '3'
            ));
        }

        Test.startTest();
        insert emails;
        Test.stopTest();

        Integer updatedCases = [
            SELECT Count()
              FROM Case
             WHERE Id IN :casesToInsert
               AND Latest_CloudPage_URL__c = 'https://example.cloudpage.co/resend/abc123'
        ];
        System.assertEquals(5, updatedCases);
    }
}
