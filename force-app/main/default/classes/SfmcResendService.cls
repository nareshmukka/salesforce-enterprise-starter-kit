/**
 * Description: Executes SFMC resend callouts and parses CloudPage URL responses.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class SfmcResendService {

    /**
     * Request wrapper
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

        // temporary testing payload
        public String subscriberKey;
    }

    /**
     * Response wrapper
     */
    public class ResponseWrapper {
        public Integer statusCode;
        public Boolean success;
        public String cloudPageUrl;
        public String responseBody;
        public String errorMessage;
    }

    private final ResendConfiguration.Config config;

    public SfmcResendService() {
        this(ResendConfiguration.getConfig());
    }

    public SfmcResendService(ResendConfiguration.Config config) {
        this.config = config;
    }

    /**
     * Sends resend request
     */
    public ResponseWrapper sendResend(RequestWrapper request) {

        String endpointPath =
        String.isBlank(request.newEmailAddress)
        ? config.sfmcStandardEndpoint
        : config.sfmcAlternateEndpoint;

        return performCallout(endpointPath, buildResendBody(request));
    }

    /**
     * Send all emails
     */
    public ResponseWrapper sendAll(RequestWrapper request) {

        HttpRequest httpRequest = new HttpRequest();

        // ===== Production logic preserved =====
        // httpRequest.setEndpoint(
        // 'callout:' +
        // config.sfmcNamedCredential +
        // config.sfmcSendAllEndpoint
        // );

        // ===== Temporary testing endpoint =====
        httpRequest.setEndpoint(config.testingSendAllEndpoint);

        httpRequest.setMethod('POST');

        httpRequest.setHeader('Content-Type','application/json');
        httpRequest.setHeader(
        'Authorization',
        'Bearer ' + config.sharedToken
        );

        Map<String,Object> body = new Map<String,Object>{
            'subscriberKey' => request.requesterEmail,
            'emailAddress' => request.requesterEmail,
            'confirmationCode' => request.confirmationNumber
        };

        httpRequest.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse response = http.send(httpRequest);

        ResponseWrapper wrapper = new ResponseWrapper();
        wrapper.statusCode = response.getStatusCode();
        wrapper.responseBody = response.getBody();
        wrapper.success =
        response.getStatusCode() >= 200 &&
        response.getStatusCode() < 300;

        wrapper.cloudPageUrl =
        extractCloudPageUrl(response.getBody());

        wrapper.errorMessage =
        wrapper.success
        ? null
        : response.getStatus();

        return wrapper;
    }

    /**
     * Performs resend callout
     */
    private ResponseWrapper performCallout(
    String endpointPath,
    String requestBody
    ){

        HttpRequest request = new HttpRequest();

        // ===== Production logic preserved =====
        // request.setEndpoint(
        // 'callout:' +
        // config.sfmcNamedCredential +
        // endpointPath
        // );

        // ===== Temporary testing endpoint =====
        Map<String,Object> bodyMap =
        (Map<String,Object>)JSON.deserializeUntyped(requestBody);

        String confirmationNumber =
        String.valueOf(bodyMap.get('confirmationNumber'));

        String endpoint =
        config.testingCloudPageEndpoint +
        '?confirmationCode=' +
        EncodingUtil.urlEncode(confirmationNumber,'UTF-8') +
        '&token=' +
        EncodingUtil.urlEncode(config.sharedToken,'UTF-8');

        request.setEndpoint(endpoint);

        request.setMethod('POST');
        request.setHeader('Content-Type','application/json');
        request.setBody(requestBody);

        Http http = new Http();
        HttpResponse response = http.send(request);

        ResponseWrapper wrapper = new ResponseWrapper();

        wrapper.statusCode = response.getStatusCode();
        wrapper.responseBody = response.getBody();

        wrapper.success =
        response.getStatusCode() >= 200 &&
        response.getStatusCode() < 300;

        wrapper.cloudPageUrl =
        extractCloudPageUrl(response.getBody());

        wrapper.errorMessage =
        wrapper.success
        ? null
        : response.getStatus();

        return wrapper;
    }

    /**
     * Builds resend payload
     */
    private String buildResendBody(RequestWrapper request){

        Map<String,Object> body =
        new Map<String,Object>{

        'caseId' => request.caseId,
        'caseNumber' => request.caseNumber,
        'emailMessageId' => request.emailMessageId,
        'requesterEmail' => request.requesterEmail,
        'confirmationNumber' => request.confirmationNumber,
        'idempotencyKey' => request.idempotencyKey
        };

        if(!String.isBlank(request.newEmailAddress)){
            body.put('newEmailAddress',request.newEmailAddress);
        }

        return JSON.serialize(body);
    }

    /**
     * Extracts CloudPage URL
     */
    private String extractCloudPageUrl(String rawText){

        if(String.isBlank(rawText)){
            return null;
        }

        Matcher matcher =
        Pattern.compile(
        '(?i)https?://[^\\s>\"]*cloudpage[^\\s>\"]*')
        .matcher(rawText);

        return matcher.find()
        ? matcher.group(0)
        : null;
    }
}
