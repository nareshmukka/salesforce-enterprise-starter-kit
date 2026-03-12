/**
 * Description: Provides placeholder configuration values for agent and SFMC integrations.
 * Developer: Naresh
 * Title: Senior Salesforce Developer
 */
public class ResendConfiguration {
    /**
     * Description: Wrapper for integration configuration values used by the resend workflow.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public class Config {
        public String agentName;
        public String agentNamedCredential;
        public String agentPath;
        public String sfmcNamedCredential;
        public String standardResendPath;
        public String resendToNewEmailPath;
        public String sendAllPath;
        public String supportedInboundAddressRegex;
        public String confirmationNumberRegex;
        public Integer requestTimeoutMs;
    }

    @TestVisible
    private static Config overrideConfig;

    /**
     * Description: Returns the active resend configuration with placeholder integration values.
     * @return Config Active configuration values.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    public static Config getConfig() {
        if (overrideConfig != null) {
            return overrideConfig;
        }

        Config config = new Config();
        config.agentName = 'Replace_With_Agentforce_Agent_Name';
        config.agentNamedCredential = 'Agentforce_Named_Credential';
        config.agentPath = '/services/apexrest/agent/placeholder';
        config.sfmcNamedCredential = 'SFMC_Named_Credential';
        config.standardResendPath = '/resend/standard';
        config.resendToNewEmailPath = '/resend/new-email';
        config.sendAllPath = '/resend/send-all';
        config.supportedInboundAddressRegex = '(?i).*';
        config.confirmationNumberRegex = '(?i)\\b(?:confirmation(?:\\s*number)?|conf(?:irmation)?\\s*#?)\\s*[:#-]?\\s*([A-Z0-9-]{5,20})\\b';
        config.requestTimeoutMs = 20000;
        return config;
    }

    /**
     * Description: Overrides configuration values for test execution.
     * @param config Test configuration.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    static void setOverride(Config config) {
        overrideConfig = config;
    }

    /**
     * Description: Clears any test configuration override.
     * Developer: Naresh
     * Title: Senior Salesforce Developer
     */
    @TestVisible
    static void reset() {
        overrideConfig = null;
    }
}
