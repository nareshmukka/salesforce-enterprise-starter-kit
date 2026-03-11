@IsTest
public class FT_TestSupport {
    public static Case createCaseRecord() {
        Case supportCase = new Case(
            Origin = 'Email',
            Status = 'New',
            Subject = 'Inbound resend request',
            SuppliedEmail = 'customer@example.com'
        );
        insert supportCase;
        return supportCase;
    }

    public static EmailMessage createInboundEmail(Id caseId, String subject, String body) {
        EmailMessage emailRecord = new EmailMessage(
            ParentId = caseId,
            Incoming = true,
            FromAddress = 'customer@example.com',
            ToAddress = 'support@example.com',
            Subject = subject,
            TextBody = body,
            Status = '3'
        );
        insert emailRecord;
        return emailRecord;
    }

    public static void resetTestState() {
        FT_EmailMessageTriggerHandler.reset();
        FT_InboundEmailOrchestrator.reset();
        FT_ResendConfigService.reset();
    }

    public static FT_ResendConfigService.Config buildTestConfig() {
        FT_ResendConfigService.Config config = new FT_ResendConfigService.Config();
        config.sfmcNamedCredential = 'SFMC_NC';
        config.standardResendPath = '/resend';
        config.alternateResendPath = '/resend-alt';
        config.sendAllPath = '/send-all';
        config.requestTimeoutMs = 20000;
        config.supportedInboundAddressRegex = '(?i).*';
        config.confirmationNumberRegex = '(?i)\\b(?:confirmation(?:\\s*number)?|conf(?:irmation)?\\s*#?)\\s*[:#-]?\\s*([A-Z0-9-]{5,20})\\b';
        return config;
    }

    public class SuccessHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setStatus('200 OK');
            response.setBody('{"message":"accepted","cloudPageUrl":"https://example.cloudpage.co/resend/abc123"}');
            return response;
        }
    }

    public class FailureHttpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setStatus('500 Server Error');
            response.setBody('{"message":"provider failure"}');
            return response;
        }
    }
}
