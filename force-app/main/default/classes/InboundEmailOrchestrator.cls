/**
 * Description: Orchestrates inbound EmailMessage processing from JSON agent request through deterministic resend rules and Case updates.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public without sharing class InboundEmailOrchestrator {
    /**
     * Description: Email context record used for agent request building and decision making.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class EmailData {
        public Id emailMessageId;
        public String subject;
        public String fromAddress;
        public String toAddress;
        public String textBody;
        public Datetime messageDate;
        public Boolean incoming;
    }

    /**
     * Description: Processing context built from Case and EmailMessage history.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ContextData {
        public Id caseId;
        public String caseNumber;
        public String caseSuppliedEmail;
        public String cloudPageUrl;
        public Id triggerEmailMessageId;
        public EmailData triggerEmail;
        public List<EmailData> emailHistory = new List<EmailData>();
    }

    /**
     * Description: Summary and categorization details returned from agent JSON processing.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class SummaryData {
        @AuraEnabled public String summary;
        @AuraEnabled public String category;
        @AuraEnabled public String intent;
        @AuraEnabled public String confirmationNumber;
        @AuraEnabled public String newEmailAddress;
        @AuraEnabled public Decimal confidence;
        @AuraEnabled public String requestJson;
        @AuraEnabled public String responseJson;
    }

    /**
     * Description: Resend row rendered in the Lightning table.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ResendRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String detail;
        @AuraEnabled public String newEmailAddress;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public Boolean sendAllAvailable;
    }

    /**
     * Description: Action result returned to Apex controllers and button handlers.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public SummaryData agentOutput;
        @AuraEnabled public List<ResendRow> resendRows;
    }

    /**
     * Description: Workspace view model returned to Lightning components.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class CaseUiView {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public Boolean sendAllAvailable;
        @AuraEnabled public Boolean manualReviewRequired;
        @AuraEnabled public String bannerMessage;
        @AuraEnabled public SummaryData agentOutput;
        @AuraEnabled public List<ResendRow> resendRows;
    }

    /**
     * Description: Internal decision record used to choose resend actions.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private class DecisionData {
        public String code;
        public String status;
        public String message;
        public String confirmationNumber;
        public String newEmailAddress;
        public String cloudPageUrlCandidate;
        public Boolean shouldCallSfmc = false;
        public Boolean shouldSendConfirmationRequest = false;
    }

    private final AgentIntegrationService agentIntegrationService;
    private final SfmcResendService sfmcResendService;

    /**
     * Description: Creates the orchestrator with default agent and SFMC services.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public InboundEmailOrchestrator() {
        this(new AgentIntegrationService(), new SfmcResendService());
    }

    /**
     * Description: Creates the orchestrator with injected services.
     * @param agentIntegrationService Placeholder agent integration service.
     * @param sfmcResendService SFMC resend service.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    private InboundEmailOrchestrator(AgentIntegrationService agentIntegrationService, SfmcResendService sfmcResendService) {
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
            processContext(context, true, pendingCloudPageUpdates);
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
     * Description: Builds the workspace view used by Lightning components.
     * @param caseId Case id for the workspace.
     * @return CaseUiView Current workspace data.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public CaseUiView getCaseUiView(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        ActionResult actionResult = context == null ? new ActionResult() : processContext(context, false, null);

        CaseUiView view = new CaseUiView();
        view.caseId = caseId;
        view.caseNumber = context == null ? null : context.caseNumber;
        view.status = actionResult.status;
        view.cloudPageUrl = actionResult.cloudPageUrl;
        view.sendAllAvailable = !String.isBlank(actionResult.cloudPageUrl);
        view.manualReviewRequired = actionResult.agentOutput != null && actionResult.agentOutput.confidence < 0.50;
        view.bannerMessage = view.manualReviewRequired ? 'Manual review is recommended before proceeding.' : actionResult.message;
        view.agentOutput = actionResult.agentOutput;
        view.resendRows = actionResult.resendRows;
        return view;
    }

    /**
     * Description: Executes the Send All action from the Lightning workspace.
     * @param caseId Case id selected in the workspace.
     * @return ActionResult Result of the Send All operation.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public ActionResult sendAll(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        if (context == null) {
            throw new AuraHandledException('Case not found.');
        }

        SfmcResendService.ResponseWrapper response = sfmcResendService.sendAll(buildSendAllRequest(context));
        String cloudPageUrl = firstNonBlank(response.cloudPageUrl, context.cloudPageUrl);
        stageCloudPageUrlUpdate(context, cloudPageUrl, null);

        ActionResult result = new ActionResult();
        result.success = true;
        result.status = 'COMPLETED';
        result.message = 'Send All request submitted.';
        result.cloudPageUrl = cloudPageUrl;
        result.agentOutput = analyzeContext(context);
        result.resendRows = buildRows(result.status, result.message, cloudPageUrl, result.agentOutput.newEmailAddress);
        return result;
    }

    /**
     * Description: Re-enqueues the latest inbound email for a Case.
     * @param caseId Case id to reprocess.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public void reprocessLatest(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        if (context != null && context.triggerEmailMessageId != null) {
            System.enqueueJob(new InboundEmailProcessingQueueable(new List<Id>{ context.triggerEmailMessageId }));
        }
    }

    /**
     * Description: Loads a single Case processing context for UI or Send All operations.
     * @param caseId Case id to load.
     * @return ContextData Processing context.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    ContextData loadContextForCase(Id caseId) {
        Map<Id, ContextData> contextsByCaseId = loadContexts(new Set<Id>{ caseId }, new Map<Id, Id>());
        return contextsByCaseId.get(caseId);
    }

    /**
     * Description: Processes one inbound email context from agent analysis through resend decisioning.
     * @param context Processing context.
     * @param executeActions Whether SFMC callouts and notifications should run.
     * @param pendingCloudPageUpdates Bulk update buffer for CloudPage URL changes.
     * @return ActionResult Current processing result.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private ActionResult processContext(ContextData context, Boolean executeActions, Map<Id, String> pendingCloudPageUpdates) {
        SummaryData summary = analyzeContext(context);
        DecisionData decision = decide(context, summary);
        String cloudPageUrl = firstNonBlank(context.cloudPageUrl, decision.cloudPageUrlCandidate);

        if (Boolean.TRUE.equals(executeActions)) {
            if (decision.shouldCallSfmc) {
                SfmcResendService.ResponseWrapper response = sfmcResendService.sendResend(buildResendRequest(context, decision));
                cloudPageUrl = firstNonBlank(response.cloudPageUrl, cloudPageUrl);
                stageCloudPageUrlUpdate(context, cloudPageUrl, pendingCloudPageUpdates);
            } else if (decision.shouldSendConfirmationRequest) {
                sendConfirmationRequest(context);
            } else if (!String.isBlank(decision.cloudPageUrlCandidate)) {
                cloudPageUrl = decision.cloudPageUrlCandidate;
                stageCloudPageUrlUpdate(context, cloudPageUrl, pendingCloudPageUpdates);
            }
        }

        ActionResult result = new ActionResult();
        result.success = true;
        result.status = decision.status;
        result.message = decision.message;
        result.cloudPageUrl = cloudPageUrl;
        result.agentOutput = summary;
        result.resendRows = buildRows(decision.status, decision.message, cloudPageUrl, summary.newEmailAddress);
        return result;
    }

    /**
     * Description: Builds agent JSON, invokes the placeholder agent service, and normalizes the JSON response.
     * @param context Processing context.
     * @return SummaryData Normalized agent output.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private SummaryData analyzeContext(ContextData context) {
        String requestJson = agentIntegrationService.buildRequestJson(context);
        String responseJson = agentIntegrationService.invokeAgent(requestJson);
        AgentIntegrationService.AgentResult agentResult = agentIntegrationService.normalizeResponse(requestJson, responseJson);

        SummaryData summary = new SummaryData();
        summary.summary = agentResult.summary;
        summary.category = agentResult.category;
        summary.intent = agentResult.intent;
        summary.confirmationNumber = agentResult.confirmationNumber;
        summary.newEmailAddress = agentResult.newEmailAddress;
        summary.confidence = agentResult.confidence;
        summary.requestJson = agentResult.requestJson;
        summary.responseJson = agentResult.responseJson;
        return summary;
    }

    /**
     * Description: Applies deterministic resend rules based on normalized agent output.
     * @param context Processing context.
     * @param summary Normalized agent output.
     * @return DecisionData Deterministic action decision.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private DecisionData decide(ContextData context, SummaryData summary) {
        DecisionData decision = new DecisionData();
        decision.cloudPageUrlCandidate = firstNonBlank(context.cloudPageUrl, extractCloudPageUrl(context.triggerEmail == null ? null : context.triggerEmail.textBody));

        if (summary.intent == 'SEND_ALL') {
            decision.code = 'NOT_RESEND';
            decision.status = 'MANUAL_REVIEW';
            decision.message = 'Send All can only be executed from the workspace button.';
            return decision;
        }

        if (summary.intent != 'RESEND') {
            decision.code = 'NOT_RESEND';
            decision.status = 'NO_ACTION';
            decision.message = 'Inbound email does not meet resend automation criteria.';
            return decision;
        }

        decision.confirmationNumber = firstNonBlank(summary.confirmationNumber, parseConfirmationNumber(context.triggerEmail == null ? null : context.triggerEmail.textBody));
        decision.newEmailAddress = firstNonBlank(summary.newEmailAddress, parseEmailAddress(context.triggerEmail == null ? null : context.triggerEmail.textBody));
        if (!String.isBlank(decision.newEmailAddress) && decision.newEmailAddress == context.caseSuppliedEmail) {
            decision.newEmailAddress = null;
        }

        if (String.isBlank(decision.confirmationNumber)) {
            decision.code = 'NEED_CONFIRMATION';
            decision.status = 'PENDING_INPUT';
            decision.message = 'Confirmation number required before SFMC resend can run.';
            decision.shouldSendConfirmationRequest = true;
            return decision;
        }

        decision.shouldCallSfmc = true;
        decision.status = 'COMPLETED';
        if (!String.isBlank(decision.newEmailAddress)) {
            decision.code = 'RESEND_NEW_EMAIL';
            decision.message = 'Resend will use the new email address endpoint.';
        } else {
            decision.code = 'RESEND_STANDARD';
            decision.message = 'Resend will use the standard confirmation endpoint.';
        }
        return decision;
    }

    /**
     * Description: Creates the resend request wrapper for SFMC.
     * @param context Processing context.
     * @param decision Deterministic decision.
     * @return RequestWrapper SFMC request.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private SfmcResendService.RequestWrapper buildResendRequest(ContextData context, DecisionData decision) {
        SfmcResendService.RequestWrapper request = baseRequest(context, 'RESEND');
        request.confirmationNumber = decision.confirmationNumber;
        request.newEmailAddress = decision.newEmailAddress;
        return request;
    }

    /**
     * Description: Creates the Send All request wrapper for SFMC.
     * @param context Processing context.
     * @return RequestWrapper SFMC request.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private SfmcResendService.RequestWrapper buildSendAllRequest(ContextData context) {
        return baseRequest(context, 'SEND_ALL');
    }

    /**
     * Description: Builds a base SFMC request wrapper from shared context values.
     * @param context Processing context.
     * @param actionType Action identifier.
     * @return RequestWrapper Base request.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private SfmcResendService.RequestWrapper baseRequest(ContextData context, String actionType) {
        SfmcResendService.RequestWrapper request = new SfmcResendService.RequestWrapper();
        request.caseId = context.caseId;
        request.caseNumber = context.caseNumber;
        request.emailMessageId = context.triggerEmailMessageId;
        request.requesterEmail = context.triggerEmail == null ? context.caseSuppliedEmail : context.triggerEmail.fromAddress;
        request.cloudPageUrl = context.cloudPageUrl;
        request.actionType = actionType;
        request.idempotencyKey = String.valueOf(context.caseId) + ':' + String.valueOf(context.triggerEmailMessageId) + ':' + actionType;
        return request;
    }

    /**
     * Description: Loads processing contexts keyed by Case id for trigger email ids.
     * @param emailMessageIds Trigger email ids.
     * @return Map<Id, ContextData> Contexts keyed by Case id.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private Map<Id, ContextData> loadContextsByTriggerEmailIds(Set<Id> emailMessageIds) {
        Map<Id, ContextData> contextsByCaseId = new Map<Id, ContextData>();
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            return contextsByCaseId;
        }

        Map<Id, Id> triggerEmailByCaseId = new Map<Id, Id>();
        Set<Id> caseIds = new Set<Id>();
        for (EmailMessage emailRecord : [
            SELECT Id, ParentId
              FROM EmailMessage
             WHERE Id IN :emailMessageIds
        ]) {
            if (emailRecord.ParentId != null && emailRecord.ParentId.getSObjectType() == Case.SObjectType) {
                caseIds.add(emailRecord.ParentId);
                triggerEmailByCaseId.put(emailRecord.ParentId, emailRecord.Id);
            }
        }

        return loadContexts(caseIds, triggerEmailByCaseId);
    }

    /**
     * Description: Loads Case and EmailMessage history for the supplied Cases.
     * @param caseIds Case ids to load.
     * @param triggerEmailByCaseId Trigger email ids keyed by Case.
     * @return Map<Id, ContextData> Processing contexts keyed by Case id.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private Map<Id, ContextData> loadContexts(Set<Id> caseIds, Map<Id, Id> triggerEmailByCaseId) {
        Map<Id, ContextData> contextsByCaseId = new Map<Id, ContextData>();
        if (caseIds == null || caseIds.isEmpty()) {
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

        for (EmailMessage emailRecord : [
            SELECT Id, ParentId, Incoming, FromAddress, ToAddress, Subject, TextBody, MessageDate
              FROM EmailMessage
             WHERE ParentId IN :caseIds
             ORDER BY MessageDate DESC, CreatedDate DESC
        ]) {
            ContextData context = contextsByCaseId.get(emailRecord.ParentId);
            if (context == null) {
                continue;
            }

            EmailData emailData = new EmailData();
            emailData.emailMessageId = emailRecord.Id;
            emailData.subject = emailRecord.Subject;
            emailData.fromAddress = emailRecord.FromAddress;
            emailData.toAddress = emailRecord.ToAddress;
            emailData.textBody = emailRecord.TextBody;
            emailData.messageDate = emailRecord.MessageDate;
            emailData.incoming = emailRecord.Incoming;
            context.emailHistory.add(emailData);

            if (triggerEmailByCaseId.containsKey(emailRecord.ParentId) && triggerEmailByCaseId.get(emailRecord.ParentId) == emailRecord.Id) {
                context.triggerEmailMessageId = emailRecord.Id;
                context.triggerEmail = emailData;
            } else if (context.triggerEmail == null && emailData.incoming == true) {
                context.triggerEmailMessageId = emailRecord.Id;
                context.triggerEmail = emailData;
            }
        }

        return contextsByCaseId;
    }

    /**
     * Description: Stages or performs the Case CloudPage URL update.
     * @param context Processing context.
     * @param cloudPageUrl New CloudPage URL.
     * @param pendingCloudPageUpdates Optional bulk update buffer.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void stageCloudPageUrlUpdate(ContextData context, String cloudPageUrl, Map<Id, String> pendingCloudPageUpdates) {
        if (context == null || context.caseId == null || String.isBlank(cloudPageUrl) || context.cloudPageUrl == cloudPageUrl) {
            return;
        }
        context.cloudPageUrl = cloudPageUrl;
        if (pendingCloudPageUpdates == null) {
            update new Case(
                Id = context.caseId,
                Latest_CloudPage_URL__c = cloudPageUrl
            );
        } else {
            pendingCloudPageUpdates.put(context.caseId, cloudPageUrl);
        }
    }

    /**
     * Description: Sends a confirmation request email when no confirmation number was detected.
     * @param context Processing context.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private void sendConfirmationRequest(ContextData context) {
        String targetEmail = context.triggerEmail == null ? context.caseSuppliedEmail : context.triggerEmail.fromAddress;
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
     * Description: Builds the resend table rows for the workspace.
     * @param status Current status label.
     * @param message Current detail message.
     * @param cloudPageUrl Current CloudPage URL.
     * @param newEmailAddress Detected new email address.
     * @return List<ResendRow> Table rows.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private List<ResendRow> buildRows(String status, String message, String cloudPageUrl, String newEmailAddress) {
        ResendRow row = new ResendRow();
        row.rowKey = 'latest';
        row.label = 'Latest resend state';
        row.status = status;
        row.detail = message;
        row.newEmailAddress = newEmailAddress;
        row.cloudPageUrl = cloudPageUrl;
        row.sendAllAvailable = !String.isBlank(cloudPageUrl);
        return new List<ResendRow>{ row };
    }

    /**
     * Description: Parses a confirmation number directly from the inbound email body.
     * @param rawText Email body text.
     * @return String Confirmation number.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    private String parseConfirmationNumber(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile(ResendConfiguration.getConfig().confirmationNumberRegex).matcher(rawText);
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
     * Description: Parses the first email address from the inbound email body.
     * @param rawText Email body text.
     * @return String Email address.
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
     * Description: Extracts a CloudPage URL from raw text.
     * @param rawText Response or email body text.
     * @return String CloudPage URL.
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
