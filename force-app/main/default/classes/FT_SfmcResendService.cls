public class FT_SfmcResendService {
    public class RequestWrapper {
        public Id caseId;
        public String caseNumber;
        public Id emailMessageId;
        public String requesterEmail;
        public String confirmationNumber;
        public String newEmail;
        public String cloudPageUrl;
        public String actionType;
        public String idempotencyKey;
    }

    public class ResponseWrapper {
        public Boolean success;
        public Integer statusCode;
        public String message;
        public String cloudPageUrl;
        public String rawBody;
    }

    private final FT_ResendConfigService.Config config;

    public FT_SfmcResendService() {
        this(FT_ResendConfigService.getConfig());
    }

    public FT_SfmcResendService(FT_ResendConfigService.Config config) {
        this.config = config;
    }

    public ResponseWrapper sendResend(RequestWrapper request) {
        String path = request.actionType == 'ALTERNATE_RESEND' ? config.alternateResendPath : config.standardResendPath;
        return invoke(path, JSON.serialize(request));
    }

    public ResponseWrapper sendAll(RequestWrapper request) {
        return invoke(config.sendAllPath, JSON.serialize(request));
    }

    private ResponseWrapper invoke(String path, String payload) {
        if (String.isBlank(config.sfmcNamedCredential) || String.isBlank(path)) {
            throw new FT_ApplicationException('SFMC configuration is incomplete.');
        }

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
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (parsed.containsKey('cloudPageUrl') && parsed.get('cloudPageUrl') != null) {
                    result.cloudPageUrl = String.valueOf(parsed.get('cloudPageUrl'));
                }
                if (parsed.containsKey('message') && parsed.get('message') != null) {
                    result.message = String.valueOf(parsed.get('message'));
                }
            } catch (Exception ex) {
                // Ignore body parsing failures and keep the raw response.
            }
        }

        if (!result.success) {
            throw new FT_ApplicationException('SFMC call failed: ' + result.message);
        }
        return result;
    }

    private String extractCloudPageUrl(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile('(?i)https?://[^\\s>\"]*cloudpage[^\\s>\"]*').matcher(rawText);
        return matcher.find() ? matcher.group(0) : null;
    }
}
