@IsTest
/**
 * Description: Provides shared data builders and callout mocks for inbound email resend tests.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class CaseEmailTestSupport {
    /**
     * Description: Creates a Case record for inbound email tests.
     * @return Case Inserted Case record.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
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

    /**
     * Description: Creates an inbound EmailMessage record for the supplied Case.
     * @param caseId Related Case id.
     * @param subject Email subject.
     * @param body Email body.
     * @return EmailMessage Inserted EmailMessage.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
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

    /**
     * Description: Resets static test state for handler, configuration, and agent placeholder services.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static void resetTestState() {
        EmailMessageTriggerHandler.reset();
        ResendConfiguration.reset();
        AgentIntegrationService.reset();
    }

    /**
     * Description: Builds a placeholder configuration for tests.
     * @return Config Test configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static ResendConfiguration.Config buildTestConfig() {
        ResendConfiguration.Config config = new ResendConfiguration.Config();
        config.agentName = 'TestAgent';
        config.agentNamedCredential = 'Agentforce_Named_Credential';
        config.agentPath = '/services/apexrest/agent/placeholder';
        config.sfmcNamedCredential = 'SFMC_Named_Credential';
        config.standardResendPath = '/resend/standard';
        config.resendToNewEmailPath = '/resend/new-email';
        config.sendAllPath = '/resend/send-all';
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
