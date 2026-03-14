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
        System.debug(LoggingLevel.ERROR, '### ORCH V4 processEmailMessages START ### emailMessageIds=' + emailMessageIds);

        Map<Id, ContextData> contextsByCaseId = loadContextsByTriggerEmailIds(emailMessageIds);
        System.debug(LoggingLevel.ERROR, '### ORCH V4 contextsByCaseId size ### ' + contextsByCaseId.size());

        Map<Id, String> pendingCloudPageUpdates = new Map<Id, String>();

        for (ContextData context : contextsByCaseId.values()) {
            System.debug(LoggingLevel.ERROR,
                '### ORCH V4 looping context ### caseId=' + context.caseId +
                ', emailMessageId=' + context.triggerEmailMessageId
            );
            processContext(context, pendingCloudPageUpdates);
        }

        System.debug(LoggingLevel.ERROR, '### ORCH V4 pendingCloudPageUpdates size ### ' + pendingCloudPageUpdates.size());
        System.debug(LoggingLevel.ERROR, '### ORCH V4 pendingCloudPageUpdates ### ' + JSON.serialize(pendingCloudPageUpdates));

        if (!pendingCloudPageUpdates.isEmpty()) {
            List<Case> casesToUpdate = new List<Case>();
            for (Id caseId : pendingCloudPageUpdates.keySet()) {
                casesToUpdate.add(new Case(
                    Id = caseId,
                    Latest_CloudPage_URL__c = pendingCloudPageUpdates.get(caseId)
                ));
            }

            System.debug(LoggingLevel.ERROR, '### ORCH V4 updating cases ### ' + JSON.serialize(casesToUpdate));
            update casesToUpdate;
            System.debug(LoggingLevel.ERROR, '### ORCH V4 case update complete ###');
        }

        System.debug(LoggingLevel.ERROR, '### ORCH V4 processEmailMessages END ###');
    }

    /**
     * Description: Processes one context through agent invocation, rules, and SFMC execution.
     * @param context Loaded trigger-path context.
     * @param pendingCloudPageUpdates Bulk update buffer.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void processContext(ContextData context, Map<Id, String> pendingCloudPageUpdates) {
        System.debug(LoggingLevel.ERROR,
            '### ORCH V4 processContext START ### caseId=' + context.caseId +
            ', caseNumber=' + context.caseNumber +
            ', triggerEmailMessageId=' + context.triggerEmailMessageId +
            ', triggerEmailFromAddress=' + context.triggerEmailFromAddress
        );

        String requestJson = agentIntegrationService.buildRequestJson(context.caseId, context.triggerEmailMessageId);
        System.debug(LoggingLevel.ERROR, '### ORCH V4 requestJson ### ' + requestJson);

        String responseJson = agentIntegrationService.invokeAgent(requestJson);
        System.debug(LoggingLevel.ERROR, '### ORCH V4 raw responseJson ### ' + responseJson);

        AgentIntegrationService.AgentResult agentResult;
        ResendIntentRulesEngine.DecisionResult decision;

        try {
            agentResult = agentIntegrationService.normalizeResponse(requestJson, responseJson);
            System.debug(LoggingLevel.ERROR, '### ORCH V4 AGENT RESULT ### ' + JSON.serialize(agentResult));

            ResendIntentRulesEngine.DecisionRequest decisionRequest = new ResendIntentRulesEngine.DecisionRequest();
            decisionRequest.caseId = context.caseId;
            decisionRequest.caseNumber = context.caseNumber;
            decisionRequest.caseSuppliedEmail = context.caseSuppliedEmail;
            decisionRequest.existingCloudPageUrl = context.cloudPageUrl;
            decisionRequest.inboundEmailBody = context.triggerEmailBody;
            decisionRequest.agentResult = agentResult;

            System.debug(LoggingLevel.ERROR, '### ORCH V4 DECISION REQUEST ### ' + JSON.serialize(decisionRequest));

            decision = ResendIntentRulesEngine.decide(decisionRequest);
            System.debug(LoggingLevel.ERROR, '### ORCH V4 DECISION RESULT ### ' + JSON.serialize(decision));

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 ERROR IN NORMALIZE/DECISION ### ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, '### ORCH V4 STACK ### ' + ex.getStackTraceString());
            return;
        }

        if (decision.shouldSendConfirmationRequest) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 sending confirmation request email ###');
            sendConfirmationRequest(context);
            return;
        }

        if (!decision.shouldCallSfmc) {
            System.debug(LoggingLevel.ERROR,
                '### ORCH V4 skipping SFMC ### shouldCallSfmc=' + decision.shouldCallSfmc +
                ', code=' + decision.code +
                ', confirmationNumber=' + decision.confirmationNumber +
                ', newEmailAddress=' + decision.newEmailAddress +
                ', cloudPageUrlCandidate=' + decision.cloudPageUrlCandidate
            );

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

        System.debug(LoggingLevel.ERROR, '### ORCH V4 BEFORE SFMC CALL ### ' + JSON.serialize(sfmcRequest));

        try {
            SfmcResendService.ResponseWrapper sfmcResponse = sfmcResendService.sendResend(sfmcRequest);
            System.debug(LoggingLevel.ERROR, '### ORCH V4 AFTER SFMC CALL ### ' + JSON.serialize(sfmcResponse));

            String cloudPageUrl = firstNonBlank(sfmcResponse.cloudPageUrl, decision.cloudPageUrlCandidate);
            System.debug(LoggingLevel.ERROR, '### ORCH V4 final cloudPageUrl ### ' + cloudPageUrl);

            if (!String.isBlank(cloudPageUrl)) {
                stageCloudPageUrlUpdate(context, cloudPageUrl, pendingCloudPageUpdates);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 ERROR IN SFMC CALL ### ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, '### ORCH V4 SFMC STACK ### ' + ex.getStackTraceString());
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
        System.debug(LoggingLevel.ERROR, '### ORCH V4 loadContexts START ### emailMessageIds=' + emailMessageIds);

        Map<Id, ContextData> contextsByCaseId = new Map<Id, ContextData>();
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 loadContexts no emailMessageIds ###');
            return contextsByCaseId;
        }

        Set<Id> caseIds = new Set<Id>();
        Map<Id, EmailMessage> triggerEmailsById = new Map<Id, EmailMessage>([
            SELECT Id, ParentId, FromAddress, Subject, TextBody
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ]);

        System.debug(LoggingLevel.ERROR, '### ORCH V4 triggerEmailsById size ### ' + triggerEmailsById.size());

        for (EmailMessage emailRecord : triggerEmailsById.values()) {
            System.debug(LoggingLevel.ERROR,
                '### ORCH V4 trigger email ### Id=' + emailRecord.Id +
                ', ParentId=' + emailRecord.ParentId +
                ', FromAddress=' + emailRecord.FromAddress
            );

            if (emailRecord.ParentId != null &&
                emailRecord.ParentId.getSObjectType() == Case.SObjectType) {
                caseIds.add(emailRecord.ParentId);
            }
        }

        System.debug(LoggingLevel.ERROR, '### ORCH V4 caseIds ### ' + caseIds);

        if (caseIds.isEmpty()) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 no caseIds found ###');
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

            System.debug(LoggingLevel.ERROR,
                '### ORCH V4 loaded case context ### caseId=' + context.caseId +
                ', caseNumber=' + context.caseNumber +
                ', suppliedEmail=' + context.caseSuppliedEmail +
                ', existingCloudPageUrl=' + context.cloudPageUrl
            );
        }

        for (EmailMessage emailRecord : triggerEmailsById.values()) {
            ContextData context = contextsByCaseId.get(emailRecord.ParentId);
            if (context == null) {
                continue;
            }
            context.triggerEmailMessageId = emailRecord.Id;
            context.triggerEmailBody = emailRecord.TextBody;
            context.triggerEmailFromAddress = emailRecord.FromAddress;

            System.debug(LoggingLevel.ERROR,
                '### ORCH V4 merged email into context ### caseId=' + context.caseId +
                ', triggerEmailMessageId=' + context.triggerEmailMessageId +
                ', triggerEmailFromAddress=' + context.triggerEmailFromAddress
            );
        }

        System.debug(LoggingLevel.ERROR, '### ORCH V4 loadContexts END ### contextsByCaseId size=' + contextsByCaseId.size());
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
        System.debug(LoggingLevel.ERROR,
            '### ORCH V4 stageCloudPageUrlUpdate START ### caseId=' +
            (context == null ? null : context.caseId) +
            ', incomingCloudPageUrl=' + cloudPageUrl
        );

        if (context == null ||
            context.caseId == null ||
            String.isBlank(cloudPageUrl) ||
            context.cloudPageUrl == cloudPageUrl) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 stageCloudPageUrlUpdate skipped ###');
            return;
        }

        context.cloudPageUrl = cloudPageUrl;
        pendingCloudPageUpdates.put(context.caseId, cloudPageUrl);

        System.debug(LoggingLevel.ERROR,
            '### ORCH V4 staged CloudPage URL ### caseId=' + context.caseId +
            ', cloudPageUrl=' + cloudPageUrl
        );
    }

    /**
     * Description: Sends a confirmation-request email when no confirmation number was detected.
     * @param context Loaded processing context.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void sendConfirmationRequest(ContextData context) {
        String targetEmail = firstNonBlank(context.triggerEmailFromAddress, context.caseSuppliedEmail);
        System.debug(LoggingLevel.ERROR,
            '### ORCH V4 sendConfirmationRequest ### targetEmail=' + targetEmail +
            ', caseNumber=' + context.caseNumber
        );

        if (String.isBlank(targetEmail)) {
            System.debug(LoggingLevel.ERROR, '### ORCH V4 sendConfirmationRequest skipped because targetEmail blank ###');
            return;
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(new List<String>{ targetEmail });
        message.setSubject('Confirmation number needed for Case ' + context.caseNumber);
        message.setPlainTextBody('We can resend your communication once you reply with the confirmation number.');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ message });

        System.debug(LoggingLevel.ERROR, '### ORCH V4 confirmation request email sent ###');
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
