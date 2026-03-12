/**
 * Description: Sends resend and Send All requests to SFMC and parses JSON responses.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class SfmcResendService {
    /**
     * Description: Request wrapper sent to SFMC.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class RequestWrapper {
        public Id caseId;
        public String caseNumber;
        public Id emailMessageId;
        public String requesterEmail;
        public String confirmationNumber;
        public String newEmailAddress;
        public String cloudPageUrl;
        public String actionType;
        public String idempotencyKey;
    }

    /**
     * Description: Response wrapper returned from SFMC.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ResponseWrapper {
        public Boolean success;
        public Integer statusCode;
        public String message;
        public String cloudPageUrl;
        public String rawBody;
    }

    private final ResendConfiguration.Config config;

    /**
     * Description: Creates the SFMC resend service using active configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public SfmcResendService() {
        this(ResendConfiguration.getConfig());
    }

    /**
     * Description: Creates the SFMC resend service using supplied configuration.
     * @param config Active resend configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public SfmcResendService(ResendConfiguration.Config config) {
        this.config = config;
    }

    /**
     * Description: Calls the correct resend endpoint based on whether a new email address exists.
     * @param request SFMC resend request.
     * @return ResponseWrapper Parsed SFMC response.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public ResponseWrapper sendResend(RequestWrapper request) {
        String path = String.isBlank(request.newEmailAddress) ? config.standardResendPath : config.resendToNewEmailPath;
        return invoke(path, JSON.serialize(request));
    }

    /**
     * Description: Calls the Send All endpoint in SFMC.
     * @param request SFMC Send All request.
     * @return ResponseWrapper Parsed SFMC response.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public ResponseWrapper sendAll(RequestWrapper request) {
        return invoke(config.sendAllPath, JSON.serialize(request));
    }

    /**
     * Description: Performs the SFMC HTTP callout and maps the JSON response.
     * @param path Endpoint path relative to the placeholder Named Credential.
     * @param payload JSON payload body.
     * @return ResponseWrapper Parsed response details.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private ResponseWrapper invoke(String path, String payload) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint('callout:' + config.sfmcNamedCredential + path);
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(config.requestTimeoutMs);
        request.setBody(payload);

        HttpResponse response = new Http().send(request);
        ResponseWrapper result = new ResponseWrapper();
        result.statusCode = response.getStatusCode();
        result.success = response.getStatusCode() >= 200 && response.getStatusCode() < 300;
        result.message = response.getStatus();
        result.rawBody = response.getBody();
        result.cloudPageUrl = extractCloudPageUrl(response.getBody());

        if (!String.isBlank(response.getBody())) {
            try {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (bodyMap.containsKey('cloudPageUrl') && bodyMap.get('cloudPageUrl') != null) {
                    result.cloudPageUrl = String.valueOf(bodyMap.get('cloudPageUrl'));
                }
                if (bodyMap.containsKey('message') && bodyMap.get('message') != null) {
                    result.message = String.valueOf(bodyMap.get('message'));
                }
            } catch (Exception ex) {
                // Keep raw response parsing fallback.
            }
        }

        if (!result.success) {
            throw new ApplicationException('SFMC call failed: ' + result.message);
        }
        return result;
    }

    /**
     * Description: Extracts the CloudPage URL from a raw SFMC response body.
     * @param rawText Raw response text.
     * @return String Extracted CloudPage URL.
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
