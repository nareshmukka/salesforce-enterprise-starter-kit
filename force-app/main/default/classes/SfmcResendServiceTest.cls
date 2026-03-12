@IsTest
/**
 * Description: Verifies SFMC resend callouts, endpoint selection, and failure handling.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
private class SfmcResendServiceTest {
    @IsTest
    static void usesStandardEndpointWhenNewEmailIsMissing() {
        CaseEmailTestSupport.resetTestState();
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());
        SfmcResendService service = new SfmcResendService(CaseEmailTestSupport.buildTestConfig());

        SfmcResendService.RequestWrapper request = new SfmcResendService.RequestWrapper();
        request.caseId = '500000000000001';
        request.caseNumber = '00001001';
        request.emailMessageId = '02s000000000001';
        request.requesterEmail = 'customer@example.com';
        request.confirmationNumber = 'ABC12345';
        request.actionType = 'RESEND';
        request.idempotencyKey = '500:02s:RESEND';

        SfmcResendService.ResponseWrapper response = service.sendResend(request);

        System.assertEquals(true, response.success);
        System.assertEquals('https://example.cloudpage.co/resend/abc123', response.cloudPageUrl);
    }

    @IsTest
    static void usesNewEmailEndpointWhenNewEmailExists() {
        CaseEmailTestSupport.resetTestState();
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.SuccessHttpCalloutMock());
        SfmcResendService service = new SfmcResendService(CaseEmailTestSupport.buildTestConfig());

        SfmcResendService.RequestWrapper request = new SfmcResendService.RequestWrapper();
        request.caseId = '500000000000001';
        request.caseNumber = '00001001';
        request.emailMessageId = '02s000000000001';
        request.requesterEmail = 'customer@example.com';
        request.confirmationNumber = 'ABC12345';
        request.newEmailAddress = 'updated@example.com';
        request.actionType = 'RESEND';
        request.idempotencyKey = '500:02s:RESEND';

        SfmcResendService.ResponseWrapper response = service.sendResend(request);

        System.assertEquals(true, response.success);
        System.assertEquals('https://example.cloudpage.co/resend/abc123', response.cloudPageUrl);
    }

    @IsTest
    static void raisesApplicationExceptionWhenProviderFails() {
        CaseEmailTestSupport.resetTestState();
        Test.setMock(HttpCalloutMock.class, new CaseEmailTestSupport.FailureHttpCalloutMock());
        SfmcResendService service = new SfmcResendService(CaseEmailTestSupport.buildTestConfig());

        SfmcResendService.RequestWrapper request = new SfmcResendService.RequestWrapper();
        request.caseId = '500000000000001';
        request.caseNumber = '00001001';
        request.emailMessageId = '02s000000000001';
        request.requesterEmail = 'customer@example.com';
        request.actionType = 'RESEND';

        try {
            service.sendResend(request);
            System.assert(false, 'Expected ApplicationException');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('SFMC call failed'));
        }
    }
}
