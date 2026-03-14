/**
 * Description: Provides centralized resend configuration for trigger-path processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class ResendConfiguration {

    /**
     * Description: Runtime configuration for resend automation.
     */
    public class Config {

        public String agentApiName;
        public String agentActionApiName;
        public String supportedInboundAddressRegex;
        public String confirmationNumberRegex;

        // ===== Existing Production Configuration =====
        public String sfmcNamedCredential;
        public String sfmcStandardEndpoint;
        public String sfmcAlternateEndpoint;
        public String sfmcSendAllEndpoint;

        // ===== Temporary Testing Configuration =====
        public String testingCloudPageEndpoint;
        public String testingSendAllEndpoint;
        public String sharedToken;
    }

    /**
     * Description: Returns the active resend configuration.
     */
    public static Config getConfig() {

        Config config = new Config();

        config.agentApiName = 'Inbound_Email_Resend_Agent';
        config.agentActionApiName = 'generateAiAgentResponse';
        config.supportedInboundAddressRegex = '.*';

        config.confirmationNumberRegex =
        '(?i)(?:confirmation\\s*(?:number|#)?\\s*[:\\-]?\\s*)([A-Z0-9\\-]+)';

        // ===== Production values (kept for future use) =====
        config.sfmcNamedCredential = 'SFMC_Named_Credential';
        config.sfmcStandardEndpoint = '/resend/confirmation';
        config.sfmcAlternateEndpoint = '/resend/confirmation-with-email';
        config.sfmcSendAllEndpoint = '/resend/send-all';

        // ===== Temporary testing endpoints =====
        config.testingCloudPageEndpoint =
        'https://REPLACE_HOST/resend/confirmation';

        config.testingSendAllEndpoint =
        'https://REPLACE_HOST/resend/send-all';

        config.sharedToken =
        'REPLACE_WITH_SHARED_TOKEN';

        return config;
    }
}
