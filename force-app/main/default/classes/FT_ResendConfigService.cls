public class FT_ResendConfigService {
    public class Config {
        public String agentNamedCredential;
        public String agentInvokePath;
        public String sfmcNamedCredential;
        public String standardResendPath;
        public String alternateResendPath;
        public String sendAllPath;
        public String supportedInboundAddressRegex;
        public String confirmationNumberRegex;
        public Integer requestTimeoutMs;
    }

    @TestVisible private static Config overrideConfig;

    public static Config getConfig() {
        if (overrideConfig != null) {
            return overrideConfig;
        }

        Config config = new Config();
        config.supportedInboundAddressRegex = '(?i).*';
        config.confirmationNumberRegex = '(?i)\\b(?:confirmation(?:\\s*number)?|conf(?:irmation)?\\s*#?)\\s*[:#-]?\\s*([A-Z0-9-]{5,20})\\b';
        config.requestTimeoutMs = 20000;

        List<FT_Resend_Settings__mdt> rows = [
            SELECT Agent_Named_Credential__c,
                   Agent_Invoke_Path__c,
                   Alternate_Resend_Path__c,
                   Confirmation_Number_Regex__c,
                   Request_Timeout_Ms__c,
                   Send_All_Path__c,
                   SFMC_Named_Credential__c,
                   Standard_Resend_Path__c,
                   Supported_Inbound_Address_Regex__c
              FROM FT_Resend_Settings__mdt
             ORDER BY DeveloperName
             LIMIT 1
        ];

        if (!rows.isEmpty()) {
            FT_Resend_Settings__mdt row = rows[0];
            config.agentNamedCredential = row.Agent_Named_Credential__c;
            config.agentInvokePath = row.Agent_Invoke_Path__c;
            config.alternateResendPath = row.Alternate_Resend_Path__c;
            config.sfmcNamedCredential = row.SFMC_Named_Credential__c;
            config.standardResendPath = row.Standard_Resend_Path__c;
            config.sendAllPath = row.Send_All_Path__c;
            if (!String.isBlank(row.Supported_Inbound_Address_Regex__c)) {
                config.supportedInboundAddressRegex = row.Supported_Inbound_Address_Regex__c;
            }
            if (!String.isBlank(row.Confirmation_Number_Regex__c)) {
                config.confirmationNumberRegex = row.Confirmation_Number_Regex__c;
            }
            if (row.Request_Timeout_Ms__c != null) {
                config.requestTimeoutMs = Integer.valueOf(row.Request_Timeout_Ms__c);
            }
        }

        return config;
    }

    @TestVisible
    static void setOverride(Config config) {
        overrideConfig = config;
    }

    @TestVisible
    static void reset() {
        overrideConfig = null;
    }
}
