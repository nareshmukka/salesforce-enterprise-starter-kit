/**
 * Description: Orchestrates trigger-path inbound EmailMessage processing from agent invocation through resend execution.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public without sharing class InboundEmailOrchestrator {
    /**
     * Description: Minimal processing context loaded for trigger-path execution.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ContextData {
        public Id caseId;
        public String caseNumber;
        public String caseSuppliedEmail;
        public String cloudPageUrl;
        public Id triggerEmailMessageId;
        public String triggerEmailBody;
        public String triggerEmailFromAddress;
    }

    private final AgentIntegrationService agentIntegrationService;
    private final SfmcResendService sfmcResendService;

    /**
     * Description: Creates the orchestrator with default services.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public InboundEmailOrchestrator() {
        this(new AgentIntegrationService(), new SfmcResendService());
    }

    /**
     * Description: Creates the orchestrator with injected services.
     * @param agentIntegrationService Agent invocation service.
     * @param sfmcResendService SFMC resend service.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    private InboundEmailOrchestrator(
        AgentIntegrationService agentIntegrationService,
        SfmcResendService sfmcResendService
    ) {
        this.agentIntegrationService = agentIntegrationService;
        this.sfmcResendService = sfmcResendService;
    }

    /**
     * Description: Processes inbound EmailMessage ids asynchronously and updates Case CloudPage URLs in bulk.
     * @param emailMessageIds Supported inbound EmailMessage ids.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public void processEmailMessages(Set<Id> emailMessageIds) {
        Map<Id, ContextData> contextsByCaseId = loadContextsByTriggerEmailIds(emailMessageIds);
        Map<Id, String> pendingCloudPageUpdates = new Map<Id, String>();

        for (ContextData context : contextsByCaseId.values()) {
            processContext(context, pendingCloudPageUpdates);
        }

        if (!pendingCloudPageUpdates.isEmpty()) {
            List<Case> casesToUpdate = new List<Case>();
            for (Id caseId : pendingCloudPageUpdates.keySet()) {
                casesToUpdate.add(new Case(
                    Id = caseId,
                    Latest_CloudPage_URL__c = pendingCloudPageUpdates.get(caseId)
                ));
            }
            update casesToUpdate;
        }
    }

    /**
     * Description: Processes one context through agent invocation, rules, and SFMC execution.
     * @param context Loaded trigger-path context.
     * @param pendingCloudPageUpdates Bulk update buffer.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void processContext(ContextData context, Map<Id, String> pendingCloudPageUpdates) {
        String requestJson = agentIntegrationService.buildRequestJson(context.caseId, context.triggerEmailMessageId);
        String responseJson = agentIntegrationService.invokeAgent(requestJson);
        AgentIntegrationService.AgentResult agentResult = agentIntegrationService.normalizeResponse(requestJson, responseJson);

        ResendIntentRulesEngine.DecisionRequest decisionRequest = new ResendIntentRulesEngine.DecisionRequest();
        decisionRequest.caseId = context.caseId;
        decisionRequest.caseNumber = context.caseNumber;
        decisionRequest.caseSuppliedEmail = context.caseSuppliedEmail;
        decisionRequest.existingCloudPageUrl = context.cloudPageUrl;
        decisionRequest.inboundEmailBody = context.triggerEmailBody;
        decisionRequest.agentResult = agentResult;

        ResendIntentRulesEngine.DecisionResult decision = ResendIntentRulesEngine.decide(decisionRequest);

        if (decision.shouldSendConfirmationRequest) {
            sendConfirmationRequest(context);
            return;
        }

        if (!decision.shouldCallSfmc) {
            if (!String.isBlank(decision.cloudPageUrlCandidate)) {
                stageCloudPageUrlUpdate(context, decision.cloudPageUrlCandidate, pendingCloudPageUpdates);
            }
            return;
        }

        SfmcResendService.RequestWrapper sfmcRequest = new SfmcResendService.RequestWrapper();
        sfmcRequest.caseId = context.caseId;
        sfmcRequest.caseNumber = context.caseNumber;
        sfmcRequest.emailMessageId = context.triggerEmailMessageId;
        sfmcRequest.requesterEmail = firstNonBlank(context.triggerEmailFromAddress, context.caseSuppliedEmail);
        sfmcRequest.actionType = decision.code;
        sfmcRequest.confirmationNumber = decision.confirmationNumber;
        sfmcRequest.newEmailAddress = decision.newEmailAddress;
        sfmcRequest.cloudPageUrl = context.cloudPageUrl;
        sfmcRequest.idempotencyKey =
            String.valueOf(context.caseId) + ':' +
            String.valueOf(context.triggerEmailMessageId) + ':' +
            decision.code;

        SfmcResendService.ResponseWrapper sfmcResponse = sfmcResendService.sendResend(sfmcRequest);
        String cloudPageUrl = firstNonBlank(sfmcResponse.cloudPageUrl, decision.cloudPageUrlCandidate);

        if (!String.isBlank(cloudPageUrl)) {
            stageCloudPageUrlUpdate(context, cloudPageUrl, pendingCloudPageUpdates);
        }
    }

    /**
     * Description: Loads trigger-path contexts keyed by Case id for the supplied EmailMessage ids.
     * @param emailMessageIds Trigger EmailMessage ids.
     * @return Map<Id, ContextData> Loaded contexts keyed by Case id.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private Map<Id, ContextData> loadContextsByTriggerEmailIds(Set<Id> emailMessageIds) {
        Map<Id, ContextData> contextsByCaseId = new Map<Id, ContextData>();
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            return contextsByCaseId;
        }

        Set<Id> caseIds = new Set<Id>();
        Map<Id, EmailMessage> triggerEmailsById = new Map<Id, EmailMessage>([
            SELECT Id, ParentId, FromAddress, Subject, TextBody
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ]);

        for (EmailMessage emailRecord : triggerEmailsById.values()) {
            if (emailRecord.ParentId != null &&
                emailRecord.ParentId.getSObjectType() == Case.SObjectType) {
                caseIds.add(emailRecord.ParentId);
            }
        }

        if (caseIds.isEmpty()) {
            return contextsByCaseId;
        }

        for (Case supportCase : [
            SELECT Id, CaseNumber, SuppliedEmail, Latest_CloudPage_URL__c
            FROM Case
            WHERE Id IN :caseIds
        ]) {
            ContextData context = new ContextData();
            context.caseId = supportCase.Id;
            context.caseNumber = supportCase.CaseNumber;
            context.caseSuppliedEmail = supportCase.SuppliedEmail;
            context.cloudPageUrl = supportCase.Latest_CloudPage_URL__c;
            contextsByCaseId.put(supportCase.Id, context);
        }

        for (EmailMessage emailRecord : triggerEmailsById.values()) {
            ContextData context = contextsByCaseId.get(emailRecord.ParentId);
            if (context == null) {
                continue;
            }
            context.triggerEmailMessageId = emailRecord.Id;
            context.triggerEmailBody = emailRecord.TextBody;
            context.triggerEmailFromAddress = emailRecord.FromAddress;
        }

        return contextsByCaseId;
    }

    /**
     * Description: Stages a Case CloudPage URL update.
     * @param context Loaded processing context.
     * @param cloudPageUrl New CloudPage URL.
     * @param pendingCloudPageUpdates Bulk update buffer.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void stageCloudPageUrlUpdate(ContextData context, String cloudPageUrl, Map<Id, String> pendingCloudPageUpdates) {
        if (context == null ||
            context.caseId == null ||
            String.isBlank(cloudPageUrl) ||
            context.cloudPageUrl == cloudPageUrl) {
            return;
        }

        context.cloudPageUrl = cloudPageUrl;
        pendingCloudPageUpdates.put(context.caseId, cloudPageUrl);
    }

    /**
     * Description: Sends a confirmation-request email when no confirmation number was detected.
     * @param context Loaded processing context.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void sendConfirmationRequest(ContextData context) {
        String targetEmail = firstNonBlank(context.triggerEmailFromAddress, context.caseSuppliedEmail);
        if (String.isBlank(targetEmail)) {
            return;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String>{ targetEmail });
        message.setSubject('Confirmation number needed for Case ' + context.caseNumber);
        message.setPlainTextBody('We can resend your communication once you reply with the confirmation number.');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ message });
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