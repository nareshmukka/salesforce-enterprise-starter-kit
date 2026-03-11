public without sharing class FT_InboundEmailOrchestrator {
    public class SummaryData {
        @AuraEnabled public String summary;
        @AuraEnabled public String historySummary;
        @AuraEnabled public String detectedIntent;
        @AuraEnabled public String candidateConfirmationNumber;
        @AuraEnabled public String candidateNewEmail;
        @AuraEnabled public Decimal confidenceScore;
        @AuraEnabled public Boolean requiresManualReview;
    }

    public class ResendRow {
        @AuraEnabled public String rowKey;
        @AuraEnabled public String label;
        @AuraEnabled public String status;
        @AuraEnabled public String detail;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public Boolean sendAllAvailable;
    }

    public class ActionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public SummaryData summary;
        @AuraEnabled public List<ResendRow> resendRows;
    }

    public class CaseUiView {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String cloudPageUrl;
        @AuraEnabled public Boolean sendAllAvailable;
        @AuraEnabled public Boolean manualReviewRequired;
        @AuraEnabled public String bannerMessage;
        @AuraEnabled public SummaryData summaryResult;
        @AuraEnabled public List<ResendRow> resendRows;
    }

    private class EmailData {
        public Id emailMessageId;
        public String subject;
        public String fromAddress;
        public String toAddress;
        public String textBody;
        public Datetime messageDate;
        public Boolean incoming;
    }

    private class ContextData {
        public Id caseId;
        public String caseNumber;
        public String caseSuppliedEmail;
        public String cloudPageUrl;
        public Id triggerEmailMessageId;
        public EmailData triggerEmail;
        public List<EmailData> emailHistory = new List<EmailData>();
    }

    private class DecisionData {
        public String code;
        public String status;
        public String message;
        public String endpointType;
        public String confirmationNumber;
        public String newEmail;
        public String cloudPageUrlCandidate;
        public Boolean shouldCallSfmc = false;
        public Boolean shouldSendConfirmationRequest = false;
    }

    private final FT_ResendConfigService.Config config;
    private final FT_SfmcResendService sfmcResendService;

    public FT_InboundEmailOrchestrator() {
        this(FT_ResendConfigService.getConfig(), new FT_SfmcResendService());
    }

    @TestVisible
    private FT_InboundEmailOrchestrator(FT_ResendConfigService.Config config, FT_SfmcResendService sfmcResendService) {
        this.config = config;
        this.sfmcResendService = sfmcResendService;
    }

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
                    FT_Latest_CloudPage_URL__c = pendingCloudPageUpdates.get(caseId)
                ));
            }
            update casesToUpdate;
        }
    }

    public CaseUiView getCaseUiView(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        ActionResult actionResult = context == null ? new ActionResult() : processContext(context, false, null);

        CaseUiView view = new CaseUiView();
        view.caseId = caseId;
        view.caseNumber = context == null ? null : context.caseNumber;
        view.status = actionResult.status;
        view.cloudPageUrl = actionResult.cloudPageUrl;
        view.sendAllAvailable = !String.isBlank(actionResult.cloudPageUrl);
        view.manualReviewRequired = actionResult.summary != null && actionResult.summary.requiresManualReview;
        view.bannerMessage = view.manualReviewRequired ? 'Manual review is recommended before proceeding.' : actionResult.message;
        view.summaryResult = actionResult.summary;
        view.resendRows = actionResult.resendRows;
        return view;
    }

    public ActionResult sendAll(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        if (context == null) {
            throw new AuraHandledException('Case not found.');
        }

        FT_SfmcResendService.RequestWrapper request = buildSendAllRequest(context);
        FT_SfmcResendService.ResponseWrapper response = sfmcResendService.sendAll(request);
        String cloudPageUrl = firstNonBlank(response.cloudPageUrl, context.cloudPageUrl);
        stageCloudPageUrlUpdate(context, cloudPageUrl, null);

        ActionResult result = new ActionResult();
        result.success = true;
        result.status = 'COMPLETED';
        result.message = 'Send All request submitted.';
        result.cloudPageUrl = cloudPageUrl;
        result.resendRows = buildRows(result.status, result.message, cloudPageUrl);
        return result;
    }

    public void reprocessLatest(Id caseId) {
        ContextData context = loadContextForCase(caseId);
        if (context != null && context.triggerEmailMessageId != null) {
            System.enqueueJob(new FT_InboundEmailProcessingQueueable(new List<Id>{ context.triggerEmailMessageId }));
        }
    }

    @TestVisible
    static String mockAgentResponse;

    @TestVisible
    static void reset() {
        mockAgentResponse = null;
    }

    @TestVisible
    ContextData loadContextForCase(Id caseId) {
        Map<Id, ContextData> contextsByCaseId = loadContexts(new Set<Id>{ caseId }, new Map<Id, Id>());
        return contextsByCaseId.get(caseId);
    }

    private ActionResult processContext(ContextData context, Boolean executeActions, Map<Id, String> pendingCloudPageUpdates) {
        SummaryData summary = analyze(context);
        DecisionData decision = decide(context, summary);
        String cloudPageUrl = firstNonBlank(context.cloudPageUrl, decision.cloudPageUrlCandidate);

        if (Boolean.TRUE.equals(executeActions)) {
            if (decision.shouldCallSfmc) {
                FT_SfmcResendService.ResponseWrapper response = sfmcResendService.sendResend(buildResendRequest(context, decision));
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
        result.summary = summary;
        result.resendRows = buildRows(decision.status, decision.message, cloudPageUrl);
        return result;
    }

    private SummaryData analyze(ContextData context) {
        String rawPayload = String.isBlank(mockAgentResponse) ? invokeAgentOrFallback(context) : mockAgentResponse;
        SummaryData summary = new SummaryData();

        if (String.isBlank(rawPayload)) {
            summary.summary = 'No agent response was returned.';
            summary.historySummary = buildHistorySummary(context.emailHistory);
            summary.detectedIntent = 'NONE';
            summary.confidenceScore = 0;
            summary.requiresManualReview = true;
            return summary;
        }

        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(rawPayload);
        summary.summary = getString(raw, 'summary');
        summary.historySummary = firstNonBlank(getString(raw, 'historySummary'), buildHistorySummary(context.emailHistory));
        summary.detectedIntent = normalizeIntent(getString(raw, 'detectedIntent'));
        summary.candidateConfirmationNumber = getString(raw, 'candidateConfirmationNumber');
        summary.candidateNewEmail = getString(raw, 'candidateNewEmail');
        summary.confidenceScore = raw.containsKey('confidenceScore') && raw.get('confidenceScore') != null
            ? Decimal.valueOf(String.valueOf(raw.get('confidenceScore')))
            : 0;
        summary.requiresManualReview = raw.containsKey('requiresManualReview') && raw.get('requiresManualReview') != null
            ? String.valueOf(raw.get('requiresManualReview')).toLowerCase() == 'true'
            : summary.confidenceScore < 0.50;

        if (String.isBlank(summary.summary) && context.triggerEmail != null) {
            summary.summary = 'Processed inbound email with subject "' + context.triggerEmail.subject + '".';
        }
        return summary;
    }

    private String invokeAgentOrFallback(ContextData context) {
        if (!String.isBlank(config.agentNamedCredential) && !String.isBlank(config.agentInvokePath)) {
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint('callout:' + config.agentNamedCredential + config.agentInvokePath);
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(config.requestTimeoutMs);
            request.setBody(JSON.serialize(context));

            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() >= 300) {
                throw new FT_ApplicationException('Agentforce invocation failed with status ' + response.getStatusCode());
            }
            return response.getBody();
        }

        Map<String, Object> fallbackPayload = new Map<String, Object>{
            'summary' => 'Inbound email reviewed for resend eligibility.',
            'historySummary' => buildHistorySummary(context.emailHistory),
            'detectedIntent' => detectIntent(context.triggerEmail == null ? null : context.triggerEmail.subject, context.triggerEmail == null ? null : context.triggerEmail.textBody),
            'candidateConfirmationNumber' => parseConfirmationNumber(context.triggerEmail == null ? null : context.triggerEmail.textBody),
            'candidateNewEmail' => parseEmailAddress(context.triggerEmail == null ? null : context.triggerEmail.textBody),
            'confidenceScore' => 0.55,
            'requiresManualReview' => false
        };
        return JSON.serialize(fallbackPayload);
    }

    private DecisionData decide(ContextData context, SummaryData summary) {
        DecisionData decision = new DecisionData();
        decision.cloudPageUrlCandidate = firstNonBlank(context.cloudPageUrl, extractCloudPageUrl(context.triggerEmail == null ? null : context.triggerEmail.textBody));

        if (summary.detectedIntent == 'SEND_ALL') {
            decision.code = 'NOT_RESEND';
            decision.status = 'MANUAL_REVIEW';
            decision.message = 'Send All can only be executed from the case workspace.';
            return decision;
        }

        if (summary.detectedIntent != 'RESEND') {
            decision.code = 'NOT_RESEND';
            decision.status = 'NO_ACTION';
            decision.message = 'Inbound email does not meet resend automation criteria.';
            return decision;
        }

        decision.confirmationNumber = firstNonBlank(summary.candidateConfirmationNumber, parseConfirmationNumber(context.triggerEmail == null ? null : context.triggerEmail.textBody));
        decision.newEmail = firstNonBlank(summary.candidateNewEmail, parseEmailAddress(context.triggerEmail == null ? null : context.triggerEmail.textBody));
        if (!String.isBlank(decision.newEmail) && decision.newEmail == context.caseSuppliedEmail) {
            decision.newEmail = null;
        }

        if (String.isBlank(decision.confirmationNumber)) {
            decision.code = 'NEED_CONFIRMATION';
            decision.status = 'PENDING_INPUT';
            decision.message = 'Confirmation number required before SFMC resend can run.';
            decision.shouldSendConfirmationRequest = true;
            return decision;
        }

        decision.shouldCallSfmc = true;
        decision.status = summary.requiresManualReview ? 'MANUAL_REVIEW' : 'COMPLETED';
        if (!String.isBlank(decision.newEmail)) {
            decision.code = 'ALTERNATE_RESEND';
            decision.endpointType = 'ALTERNATE_RESEND';
            decision.message = 'Alternate resend will be sent with the updated email address.';
        } else {
            decision.code = 'STANDARD_RESEND';
            decision.endpointType = 'STANDARD_RESEND';
            decision.message = 'Standard resend will be sent using the confirmation number.';
        }
        return decision;
    }

    private FT_SfmcResendService.RequestWrapper buildResendRequest(ContextData context, DecisionData decision) {
        FT_SfmcResendService.RequestWrapper request = baseRequest(context, decision.endpointType);
        request.confirmationNumber = decision.confirmationNumber;
        request.newEmail = decision.newEmail;
        return request;
    }

    private FT_SfmcResendService.RequestWrapper buildSendAllRequest(ContextData context) {
        return baseRequest(context, 'SEND_ALL');
    }

    private FT_SfmcResendService.RequestWrapper baseRequest(ContextData context, String actionType) {
        FT_SfmcResendService.RequestWrapper request = new FT_SfmcResendService.RequestWrapper();
        request.caseId = context.caseId;
        request.caseNumber = context.caseNumber;
        request.emailMessageId = context.triggerEmailMessageId;
        request.requesterEmail = context.triggerEmail == null ? context.caseSuppliedEmail : context.triggerEmail.fromAddress;
        request.cloudPageUrl = context.cloudPageUrl;
        request.actionType = actionType;
        request.idempotencyKey = String.valueOf(context.caseId) + ':' + String.valueOf(context.triggerEmailMessageId) + ':' + actionType;
        return request;
    }

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

    private Map<Id, ContextData> loadContexts(Set<Id> caseIds, Map<Id, Id> triggerEmailByCaseId) {
        Map<Id, ContextData> contextsByCaseId = new Map<Id, ContextData>();
        if (caseIds == null || caseIds.isEmpty()) {
            return contextsByCaseId;
        }

        for (Case supportCase : [
            SELECT Id, CaseNumber, SuppliedEmail, FT_Latest_CloudPage_URL__c
              FROM Case
             WHERE Id IN :caseIds
        ]) {
            ContextData context = new ContextData();
            context.caseId = supportCase.Id;
            context.caseNumber = supportCase.CaseNumber;
            context.caseSuppliedEmail = supportCase.SuppliedEmail;
            context.cloudPageUrl = supportCase.FT_Latest_CloudPage_URL__c;
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

    private void stageCloudPageUrlUpdate(ContextData context, String cloudPageUrl, Map<Id, String> pendingCloudPageUpdates) {
        if (context == null || context.caseId == null || String.isBlank(cloudPageUrl) || context.cloudPageUrl == cloudPageUrl) {
            return;
        }
        context.cloudPageUrl = cloudPageUrl;
        if (pendingCloudPageUpdates == null) {
            update new Case(
                Id = context.caseId,
                FT_Latest_CloudPage_URL__c = cloudPageUrl
            );
        } else {
            pendingCloudPageUpdates.put(context.caseId, cloudPageUrl);
        }
    }

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

    private List<ResendRow> buildRows(String status, String message, String cloudPageUrl) {
        ResendRow row = new ResendRow();
        row.rowKey = 'latest';
        row.label = 'Latest resend state';
        row.status = status;
        row.detail = message;
        row.cloudPageUrl = cloudPageUrl;
        row.sendAllAvailable = !String.isBlank(cloudPageUrl);
        return new List<ResendRow>{ row };
    }

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

    private String parseEmailAddress(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile('(?i)\\b([A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,})\\b').matcher(rawText);
        return matcher.find() ? matcher.group(1).trim() : null;
    }

    private String extractCloudPageUrl(String rawText) {
        if (String.isBlank(rawText)) {
            return null;
        }
        Matcher matcher = Pattern.compile('(?i)https?://[^\\s>\"]*cloudpage[^\\s>\"]*').matcher(rawText);
        return matcher.find() ? matcher.group(0) : null;
    }

    private String buildHistorySummary(List<EmailData> history) {
        Integer total = history == null ? 0 : history.size();
        Integer inboundCount = 0;
        if (history != null) {
            for (EmailData emailData : history) {
                if (emailData.incoming == true) {
                    inboundCount++;
                }
            }
        }
        return 'Reviewed ' + total + ' related emails, including ' + inboundCount + ' inbound messages.';
    }

    private String getString(Map<String, Object> values, String keyName) {
        return values.containsKey(keyName) && values.get(keyName) != null ? String.valueOf(values.get(keyName)) : null;
    }

    private String firstNonBlank(String firstValue, String secondValue) {
        return String.isBlank(firstValue) ? secondValue : firstValue;
    }
}
