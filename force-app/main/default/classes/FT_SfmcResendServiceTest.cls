@IsTest
private class FT_SfmcResendServiceTest {
    @IsTest
    static void sendsStandardPayloadAndParsesCloudPageUrl() {
        Test.setMock(HttpCalloutMock.class, new FT_TestSupport.SuccessHttpCalloutMock());

        FT_ResendConfigService.Config config = FT_TestSupport.buildTestConfig();
        FT_SfmcResendService service = new FT_SfmcResendService(config);
        FT_SfmcResendService.RequestWrapper request = new FT_SfmcResendService.RequestWrapper();
        request.caseId = '500000000000001';
        request.caseNumber = '00001001';
        request.emailMessageId = '02s000000000001';
        request.requesterEmail = 'customer@example.com';
        request.confirmationNumber = 'ABC12345';
        request.actionType = 'STANDARD_RESEND';
        request.idempotencyKey = '500:02s:STANDARD_RESEND';

        FT_SfmcResendService.ResponseWrapper responseDto = service.sendResend(request);

        System.assertEquals(true, responseDto.success);
        System.assertEquals('https://example.cloudpage.co/resend/abc123', responseDto.cloudPageUrl);
    }

    @IsTest
    static void mapsProviderFailureToApplicationException() {
        Test.setMock(HttpCalloutMock.class, new FT_TestSupport.FailureHttpCalloutMock());

        FT_ResendConfigService.Config config = FT_TestSupport.buildTestConfig();
        FT_SfmcResendService service = new FT_SfmcResendService(config);
        FT_SfmcResendService.RequestWrapper request = new FT_SfmcResendService.RequestWrapper();
        request.caseId = '500000000000001';
        request.caseNumber = '00001001';
        request.emailMessageId = '02s000000000001';
        request.requesterEmail = 'customer@example.com';
        request.actionType = 'STANDARD_RESEND';

        try {
            service.sendResend(request);
            System.assert(false, 'Expected FT_ApplicationException');
        } catch (FT_ApplicationException ex) {
            System.assert(ex.getMessage().contains('SFMC call failed'));
        }
    }
}
