/**
 * Description: Handles placeholder Agentforce request and response JSON processing for inbound email analysis.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class AgentIntegrationService {
    @TestVisible
    static String mockResponseJson;
    @TestVisible
    static String lastRequestJson;

    /**
     * Description: Agent request payload sent to the placeholder agent integration point.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class AgentRequest {
        public String agentName;
        public Id caseId;
        public Id emailMessageId;
        public String subject;
        public String body;
        public List<EmailHistoryEntry> history;
    }

    /**
     * Description: Historical email entry included in the agent request payload.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class EmailHistoryEntry {
        public String subject;
        public String body;
    }

    /**
     * Description: Normalized agent response used by the workspace and resend rules.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class AgentResult {
        @AuraEnabled public String summary;
        @AuraEnabled public String category;
        @AuraEnabled public String intent;
        @AuraEnabled public String confirmationNumber;
        @AuraEnabled public String newEmailAddress;
        @AuraEnabled public Decimal confidence;
        @AuraEnabled public String requestJson;
        @AuraEnabled public String responseJson;
    }

    private final ResendConfiguration.Config config;

    /**
     * Description: Creates the agent integration service with active configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public AgentIntegrationService() {
        this(ResendConfiguration.getConfig());
    }

    /**
     * Description: Creates the agent integration service with supplied configuration.
     * @param config Active resend configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public AgentIntegrationService(ResendConfiguration.Config config) {
        this.config = config;
    }

    /**
     * Description: Builds the agent request JSON payload using inbound email context.
     * @param context Orchestrator context for the inbound email.
     * @return String JSON payload for the placeholder agent integration point.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public String buildRequestJson(InboundEmailOrchestrator.ContextData context) {
        AgentRequest request = new AgentRequest();
        request.agentName = config.agentName;
        request.caseId = context.caseId;
        request.emailMessageId = context.triggerEmailMessageId;
        request.subject = context.triggerEmail == null ? null : context.triggerEmail.subject;
        request.body = context.triggerEmail == null ? null : context.triggerEmail.textBody;
        request.history = new List<EmailHistoryEntry>();

        for (InboundEmailOrchestrator.EmailData emailData : context.emailHistory) {
            EmailHistoryEntry entry = new EmailHistoryEntry();
            entry.subject = emailData.subject;
            entry.body = emailData.textBody;
            request.history.add(entry);
        }

        return JSON.serialize(request);
    }

    /**
     * Description: Invokes the placeholder agent integration point and returns response JSON.
     * @param requestJson JSON request payload.
     * @return String JSON response payload.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public String invokeAgent(String requestJson) {
        lastRequestJson = requestJson;
        if (!String.isBlank(mockResponseJson)) {
            return mockResponseJson;
        }

        Map<String, Object> requestMap = (Map<String, Object>) JSON.deserializeUntyped(requestJson);
        String subject = requestMap.containsKey('subject') ? String.valueOf(requestMap.get('subject')) : null;
        String body = requestMap.containsKey('body') ? String.valueOf(requestMap.get('body')) : null;

        Map<String, Object> responseMap = new Map<String, Object>{
            'summary' => 'Customer is asking for resend follow-up.',
            'category' => detectCategory(subject, body),
            'intent' => detectIntent(subject, body),
            'confirmationNumber' => parseConfirmationNumber(body),
            'newEmailAddress' => parseEmailAddress(body),
            'confidence' => 0.55
        };
        return JSON.serialize(responseMap);
    }

    /**
     * Description: Normalizes agent response JSON into a typed result for rules and UI.
     * @param requestJson Original request JSON.
     * @param responseJson Agent response JSON.
     * @return AgentResult Normalized result.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public AgentResult normalizeResponse(String requestJson, String responseJson) {
        AgentResult result = new AgentResult();
        result.requestJson = requestJson;
        result.responseJson = responseJson;

        if (String.isBlank(responseJson)) {
            result.summary = 'No agent response was returned.';
            result.category = 'Manual Review';
            result.intent = 'NONE';
            result.confidence = 0;
            return result;
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        result.summary = readString(responseMap, 'summary');
        result.category = firstNonBlank(readString(responseMap, 'category'), 'General Inquiry');
        result.intent = normalizeIntent(readString(responseMap, 'intent'));
        result.confirmationNumber = readString(responseMap, 'confirmationNumber');
        result.newEmailAddress = readString(responseMap, 'newEmailAddress');
        result.confidence = responseMap.containsKey('confidence') && responseMap.get('confidence') != null
            ? Decimal.valueOf(String.valueOf(responseMap.get('confidence')))
            : 0;
        return result;
    }

    /**
     * Description: Clears static test state for the placeholder agent integration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    static void reset() {
        mockResponseJson = null;
        lastRequestJson = null;
    }

    /**
     * Description: Returns the heuristic intent when the placeholder agent is used.
     * @param subject Email subject.
     * @param body Email body.
     * @return String Intent code.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String detectIntent(String subject, String body) {
        String combined = ((subject == null ? '' : subject) + ' ' + (body == null ? '' : body)).toLowerCase();
        if (combined.contains('send all')) {
            return 'SEND_ALL';
        }
        if (combined.contains('resend') ||
            combined.contains('send again') ||
            combined.contains('did not receive') ||
            combined.contains('missing confirmation')) {
            return 'RESEND';
        }
        return 'NONE';
    }

    /**
     * Description: Returns a simple category for placeholder agent responses.
     * @param subject Email subject.
     * @param body Email body.
     * @return String Category label.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String detectCategory(String subject, String body) {
        return detectIntent(subject, body) == 'RESEND' ? 'Resend Request' : 'General Inquiry';
    }

    /**
     * Description: Parses a confirmation number from email text.
     * @param rawText Email text.
     * @return String Confirmation number when detected.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String parseConfirmationNumber(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile(config.confirmationNumberRegex).matcher(rawText);
        if (!matcher.find()) {
            return null;
        }
        for (Integer index = 1; index <= matcher.groupCount(); index++) {
            String value = matcher.group(index);
            if (!String.isBlank(value)) {
                return value.trim();
            }
        }
        return null;
    }

    /**
     * Description: Parses an email address from free-form text.
     * @param rawText Email text.
     * @return String First detected email address.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String parseEmailAddress(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile('(?i)\\b([A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,})\\b').matcher(rawText);
        return matcher.find() ? matcher.group(1).trim() : null;
    }

    /**
     * Description: Normalizes intent strings from agent output.
     * @param rawIntent Raw agent intent value.
     * @return String Normalized intent code.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String normalizeIntent(String rawIntent) {
        if (String.isBlank(rawIntent)) {
            return 'NONE';
        }
        String normalized = rawIntent.trim().toUpperCase();
        if (normalized.contains('SEND_ALL')) {
            return 'SEND_ALL';
        }
        if (normalized.contains('RESEND')) {
            return 'RESEND';
        }
        return 'NONE';
    }

    /**
     * Description: Reads a string value from a JSON map.
     * @param source JSON map.
     * @param keyName Key to read.
     * @return String Value or null.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String readString(Map<String, Object> source, String keyName) {
        return source.containsKey(keyName) && source.get(keyName) != null ? String.valueOf(source.get(keyName)) : null;
    }

    /**
     * Description: Returns the first non-blank value in order.
     * @param firstValue Primary value.
     * @param secondValue Secondary value.
     * @return String First non-blank value.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String firstNonBlank(String firstValue, String secondValue) {
        return String.isBlank(firstValue) ? secondValue : firstValue;
    }
}
