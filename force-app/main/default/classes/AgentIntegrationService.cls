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

    @TestVisible
    static Map<String, Object> lastOutputParameters;

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
        public String sessionId;
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
        request.sessionId = null;
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

        AgentInvocationRequest request =
            (AgentInvocationRequest) JSON.deserialize(requestJson, AgentInvocationRequest.class);

        if (request == null) {
            throw new ApplicationException('Agent request payload is required.');
        }
        if (String.isBlank(request.agentApiName)) {
            throw new ApplicationException('Agent API name is missing from configuration.');
        }
        if (String.isBlank(request.userMessage)) {
            throw new ApplicationException('Agent userMessage is required.');
        }

        lastUserMessage = request.userMessage;

        System.debug('### ENTER AgentIntegrationService.invokeAgent ###');
        System.debug('### agentApiName=' + request.agentApiName);
        System.debug('### caseId=' + request.caseId);
        System.debug('### emailMessageId=' + request.emailMessageId);
        System.debug('### userMessage=' + request.userMessage);

        try {
            Invocable.Action action =
                Invocable.Action.createCustomAction('generateAiAgentResponse', request.agentApiName);

            action.setInvocationParameter('userMessage', request.userMessage);

            if (!String.isBlank(request.sessionId)) {
                action.setInvocationParameter('sessionId', request.sessionId);
            }

            List<Invocable.Action.Result> results = action.invoke();
            if (results == null || results.isEmpty()) {
                throw new ApplicationException('Agent invocation returned no results.');
            }

            Invocable.Action.Result firstResult = results[0];
            Map<String, Object> outputParameters =
                firstResult.getOutputParameters() == null
                ? new Map<String, Object>()
                : firstResult.getOutputParameters();

            lastOutputParameters = outputParameters;

            System.debug('### outputParameters=' + JSON.serialize(outputParameters));

            String responsePayload = extractAgentResponsePayload(outputParameters);
            String normalizedPayload = normalizeAgentPayload(responsePayload);

            System.debug('### normalizedPayload=' + normalizedPayload);

            return normalizedPayload;
        } catch (Exception ex) {
            throw new ApplicationException('Agent invocation failed: ' + ex.getMessage());
        }
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

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(responseJson);

        result.summary = readString(responseMap, 'summary');
        result.historySummary = readString(responseMap, 'historySummary');
        result.category = firstNonBlank(readString(responseMap, 'category'), 'Unknown');
        result.intent = normalizeIntent(readString(responseMap, 'intent'));
        result.confirmationNumber = readString(responseMap, 'confirmationNumber');
        result.newEmailAddress = readString(responseMap, 'newEmailAddress');
        result.confidence =
            responseMap.containsKey('confidence') && responseMap.get('confidence') != null
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
        lastOutputParameters = null;
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
     * Description: Extracts the primary response payload from agent output parameters.
     * @param outputParameters Output parameters returned by the invocable action.
     * @return String Raw response payload.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String extractAgentResponsePayload(Map<String, Object> outputParameters) {
        if (outputParameters == null || outputParameters.isEmpty()) {
            return null;
        }

        for (String preferredKey : new List<String>{ 'agentResponse', 'response', 'result', 'output', 'value' }) {
            if (outputParameters.containsKey(preferredKey) && outputParameters.get(preferredKey) != null) {
                return objectToString(outputParameters.get(preferredKey));
            }
        }

        for (Object value : outputParameters.values()) {
            if (value != null) {
                return objectToString(value);
            }
        }

        return null;
    }

    /**
     * Description: Converts any agent output object into a string payload.
     * @param rawValue Output value.
     * @return String Serialized or plain string value.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String objectToString(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        if (rawValue instanceof String) {
            return String.valueOf(rawValue);
        }
        return JSON.serialize(rawValue);
    }

    /**
     * Description: Converts agent payload into the JSON contract expected by downstream logic.
     * @param rawPayload Raw payload returned by the agent action.
     * @return String Normalized JSON string.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String normalizeAgentPayload(String rawPayload) {
        if (String.isBlank(rawPayload)) {
            return JSON.serialize(buildFallbackResult('No agent response was returned.'));
        }

        String cleanedPayload = stripMarkdownFence(rawPayload);

        try {
            Object parsed = JSON.deserializeUntyped(cleanedPayload);

            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> parsedMap = (Map<String, Object>) parsed;

                if (looksLikeFinalAgentResult(parsedMap)) {
                    return JSON.serialize(parsedMap);
                }

                if (parsedMap.containsKey('value') && parsedMap.get('value') != null) {
                    return normalizeAgentPayload(String.valueOf(parsedMap.get('value')));
                }

                if (parsedMap.containsKey('agentResponse') && parsedMap.get('agentResponse') != null) {
                    return normalizeAgentPayload(String.valueOf(parsedMap.get('agentResponse')));
                }

                return JSON.serialize(buildFallbackResult(cleanedPayload));
            }

            return JSON.serialize(buildFallbackResult(String.valueOf(parsed)));
        } catch (Exception ex) {
            return JSON.serialize(buildFallbackResult(cleanedPayload));
        }
    }

    /**
     * Description: Determines whether a parsed map already matches the final downstream contract.
     * @param parsedMap Parsed response map.
     * @return Boolean True when the map looks like a final agent result.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private Boolean looksLikeFinalAgentResult(Map<String, Object> parsedMap) {
        if (parsedMap == null) {
            return false;
        }

        return parsedMap.containsKey('summary') ||
            parsedMap.containsKey('intent') ||
            parsedMap.containsKey('confirmationNumber') ||
            parsedMap.containsKey('newEmailAddress') ||
            parsedMap.containsKey('historySummary');
    }

    /**
     * Description: Removes markdown JSON fences from an agent response.
     * @param rawPayload Raw payload.
     * @return String Clean payload.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String stripMarkdownFence(String rawPayload) {
        String cleaned = rawPayload == null ? null : rawPayload.trim();

        if (String.isBlank(cleaned)) {
            return cleaned;
        }

        if (cleaned.startsWith('```json')) {
            cleaned = cleaned.substring(7).trim();
        } else if (cleaned.startsWith('```')) {
            cleaned = cleaned.substring(3).trim();
        }

        if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.length() - 3).trim();
        }

        return cleaned;
    }

    /**
     * Description: Builds a safe fallback map when agent output is not in the expected format.
     * @param summaryText Summary text.
     * @return Map<String, Object> Fallback response map.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private Map<String, Object> buildFallbackResult(String summaryText) {
        return new Map<String, Object>{
            'summary' => summaryText,
            'historySummary' => null,
            'category' => 'Unknown',
            'intent' => 'NONE',
            'confirmationNumber' => null,
            'newEmailAddress' => null,
            'confidence' => 0
        };
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
