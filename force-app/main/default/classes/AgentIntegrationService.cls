/**
 * Description: Invokes the Agentforce agent for inbound email analysis and normalizes the JSON response.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class AgentIntegrationService {
    @TestVisible
    static String mockResponseJson;

    @TestVisible
    static String lastUserMessage;

    /**
     * Description: Minimal request payload sent to the agent so it can retrieve context through actions.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class AgentInvocationRequest {
        public String agentApiName;
        public Id caseId;
        public Id emailMessageId;
        public String userMessage;
    }

    /**
     * Description: Normalized agent response used by resend rules and UI aggregation.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class AgentResult {
        @AuraEnabled public String summary;
        @AuraEnabled public String historySummary;
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
     * Description: Builds the minimal agent request JSON used for trigger-path invocation.
     * @param caseId Parent Case id.
     * @param emailMessageId Triggering EmailMessage id.
     * @return String JSON request payload.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public String buildRequestJson(Id caseId, Id emailMessageId) {
        AgentInvocationRequest request = new AgentInvocationRequest();
        request.agentApiName = config.agentApiName;
        request.caseId = caseId;
        request.emailMessageId = emailMessageId;
        request.userMessage = buildUserMessage(caseId, emailMessageId);
        return JSON.serialize(request);
    }

    /**
     * Description: Invokes the configured agent and returns the raw response JSON.
     * @param requestJson JSON request payload.
     * @return String Raw JSON response payload from the agent.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public String invokeAgent(String requestJson) {
        if (!String.isBlank(mockResponseJson)) {
            return mockResponseJson;
        }

        Map<String, Object> requestMap = (Map<String, Object>) JSON.deserializeUntyped(requestJson);
        String userMessage = requestMap.containsKey('userMessage')
            ? String.valueOf(requestMap.get('userMessage'))
            : null;

        lastUserMessage = userMessage;

        /*
         * TODO:
         * Replace this neutral fallback with the real Agentforce Invocable Action API call
         * after the agent + topic + actions are created in the org.
         *
         * Current architecture assumption:
         * - Apex invokes the agent
         * - Agent retrieves Case + Email history through Apex actions
         * - LLM summarizes and classifies
         * - JSON response is returned here
         */

        Map<String, Object> fallback = new Map<String, Object>{
            'summary' => 'Agent invocation not wired yet.',
            'historySummary' => null,
            'category' => 'Unknown',
            'intent' => 'NONE',
            'confirmationNumber' => null,
            'newEmailAddress' => null,
            'confidence' => 0
        };
        return JSON.serialize(fallback);
    }

    /**
     * Description: Normalizes raw agent response JSON into a typed result.
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
            result.historySummary = null;
            result.category = 'Unknown';
            result.intent = 'NONE';
            result.confidence = 0;
            return result;
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        result.summary = readString(responseMap, 'summary');
        result.historySummary = readString(responseMap, 'historySummary');
        result.category = firstNonBlank(readString(responseMap, 'category'), 'Unknown');
        result.intent = normalizeIntent(readString(responseMap, 'intent'));
        result.confirmationNumber = readString(responseMap, 'confirmationNumber');
        result.newEmailAddress = readString(responseMap, 'newEmailAddress');
        result.confidence = responseMap.containsKey('confidence') && responseMap.get('confidence') != null
            ? Decimal.valueOf(String.valueOf(responseMap.get('confidence')))
            : 0;

        return result;
    }

    /**
     * Description: Resets static test state.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    static void reset() {
        mockResponseJson = null;
        lastUserMessage = null;
    }

    /**
     * Description: Builds the user message passed to the agent invocation entry point.
     * @param caseId Parent Case id.
     * @param emailMessageId Triggering EmailMessage id.
     * @return String User message for the agent.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String buildUserMessage(Id caseId, Id emailMessageId) {
        return 'Analyze inbound resend email for caseId=' + String.valueOf(caseId) +
            ' and emailMessageId=' + String.valueOf(emailMessageId) +
            '. Retrieve case context and email history using available actions. ' +
            'Return JSON with summary, historySummary, category, intent, confirmationNumber, newEmailAddress, confidence.';
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
        return source.containsKey(keyName) && source.get(keyName) != null
            ? String.valueOf(source.get(keyName))
            : null;
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

    /**
     * Description: Normalizes intent values from agent JSON output.
     * @param rawIntent Raw intent value.
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
}