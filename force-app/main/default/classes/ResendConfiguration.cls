/**
 * Description: Provides centralized resend configuration for trigger-path processing.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public with sharing class ResendConfiguration {
    /**
     * Description: Runtime configuration for resend automation.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class Config {
        public String agentApiName;
        public String agentActionApiName;
        public String supportedInboundAddressRegex;
        public String confirmationNumberRegex;

        public String sfmcNamedCredential;
        public String sfmcStandardEndpoint;
        public String sfmcAlternateEndpoint;
        public String sfmcSendAllEndpoint;

        // Temporary shared-token-based testing config
        public String sharedToken;
    }

    /**
     * Description: Returns the active resend configuration.
     * @return Config Current runtime configuration values.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static Config getConfig() {
        Config config = new Config();
        config.agentApiName = 'Inbound_Email_Resend_Agent';
        config.agentActionApiName = 'generateAiAgentResponse';
        config.supportedInboundAddressRegex = '.*';
        config.confirmationNumberRegex = '(?i)(?:confirmation\\s*(?:number|#)?\\s*[:\\-]?\\s*)([A-Z0-9\\-]+)';

        config.sfmcNamedCredential = 'SFMC_Named_Credential';

        // Cloud Page URL / resend
        config.sfmcStandardEndpoint = '/resend/confirmation';

        // New email address flow - keep untouched
        config.sfmcAlternateEndpoint = '/resend/confirmation-with-email';

        // Send all emails
        config.sfmcSendAllEndpoint = '/resend/send-all';

        // Temporary testing token - replace later with secure configuration
        config.sharedToken = 'REPLACE_WITH_SHARED_TOKEN';

        return config;
    }
}
