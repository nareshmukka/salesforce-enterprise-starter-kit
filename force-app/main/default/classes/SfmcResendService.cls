/**
 * Description: Executes SFMC resend callouts and parses CloudPage URL responses.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class SfmcResendService {
    /**
     * Description: Request wrapper for SFMC resend operations.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class RequestWrapper {
        public Id caseId;
        public String caseNumber;
        public Id emailMessageId;
        public String requesterEmail;
        public String cloudPageUrl;
        public String actionType;
        public String confirmationNumber;
        public String newEmailAddress;
        public String idempotencyKey;
    }

    /**
     * Description: Response wrapper for SFMC resend operations.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ResponseWrapper {
        public Integer statusCode;
        public Boolean success;
        public String cloudPageUrl;
        public String responseBody;
        public String errorMessage;
    }

    private final ResendConfiguration.Config config;

    /**
     * Description: Creates the service using active resend configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public SfmcResendService() {
        this(ResendConfiguration.getConfig());
    }

    /**
     * Description: Creates the service with supplied resend configuration.
     * @param config Active resend configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public SfmcResendService(ResendConfiguration.Config config) {
        this.config = config;
    }

    /**
     * Description: Sends the resend request to the correct SFMC endpoint.
     * @param request Request wrapper.
     * @return ResponseWrapper Parsed response details.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public ResponseWrapper sendResend(RequestWrapper request) {
        String endpointPath = String.isBlank(request.newEmailAddress)
            ? config.sfmcStandardEndpoint
            : config.sfmcAlternateEndpoint;

        return performCallout(endpointPath, buildResendBody(request));
    }

    /**
     * Description: Sends the Send All request to SFMC.
     * @param request Request wrapper.
     * @return ResponseWrapper Parsed response details.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public ResponseWrapper sendAll(RequestWrapper request) {
        return performCallout(config.sfmcSendAllEndpoint, buildSendAllBody(request));
    }

    /**
     * Description: Performs the HTTP callout and parses the response.
     * @param endpointPath Endpoint path after the Named Credential.
     * @param requestBody JSON request body.
     * @return ResponseWrapper Parsed response details.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private ResponseWrapper performCallout(String endpointPath, String requestBody) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + config.sfmcNamedCredential + endpointPath);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(requestBody);

        Http http = new Http();
        HttpResponse response = http.send(request);

        ResponseWrapper wrapper = new ResponseWrapper();
        wrapper.statusCode = response.getStatusCode();
        wrapper.responseBody = response.getBody();
        wrapper.success = response.getStatusCode() >= 200 && response.getStatusCode() < 300;
        wrapper.cloudPageUrl = extractCloudPageUrl(response.getBody());
        wrapper.errorMessage = wrapper.success ? null : response.getStatus();

        return wrapper;
    }

    /**
     * Description: Builds the standard or alternate resend payload.
     * @param request Request wrapper.
     * @return String JSON request body.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String buildResendBody(RequestWrapper request) {
        Map<String, Object> body = new Map<String, Object>{
            'caseId' => request.caseId,
            'caseNumber' => request.caseNumber,
            'emailMessageId' => request.emailMessageId,
            'requesterEmail' => request.requesterEmail,
            'confirmationNumber' => request.confirmationNumber,
            'idempotencyKey' => request.idempotencyKey
        };

        if (!String.isBlank(request.newEmailAddress)) {
            body.put('newEmailAddress', request.newEmailAddress);
        }

        return JSON.serialize(body);
    }

    /**
     * Description: Builds the Send All payload.
     * @param request Request wrapper.
     * @return String JSON request body.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String buildSendAllBody(RequestWrapper request) {
        Map<String, Object> body = new Map<String, Object>{
            'caseId' => request.caseId,
            'caseNumber' => request.caseNumber,
            'emailMessageId' => request.emailMessageId,
            'requesterEmail' => request.requesterEmail,
            'cloudPageUrl' => request.cloudPageUrl,
            'idempotencyKey' => request.idempotencyKey
        };
        return JSON.serialize(body);
    }

    /**
     * Description: Extracts a CloudPage URL from SFMC response JSON or text.
     * @param rawText Raw response body.
     * @return String CloudPage URL when present.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String extractCloudPageUrl(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }

        Matcher matcher = Pattern.compile('(?i)https?://[^\\s>\"]*cloudpage[^\\s>\"]*').matcher(rawText);
        return matcher.find() ? matcher.group(0) : null;
    }
}