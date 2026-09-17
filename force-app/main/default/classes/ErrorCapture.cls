/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ErrorCapture {

    private static final String NAMED_CREDENTIAL = 'callout:Triage_Agent_Named_Creds';
    private static final String APP_NAME = 'AccountForge';
    private static final String DEFAULT_PRIORITY = 'high';

    // Fill these in once the GitHub repo for this project exists.
    private static final String REPO_OWNER = 'anirban-saksoft';
    private static final String REPO_NAME = 'accountforge-app';

    public class ErrorPayload {
        @InvocableVariable(label='Error Type' required=false)
        public String errorType;

        @InvocableVariable(label='Error Message' required=true)
        public String errorMessage;

        @InvocableVariable(label='Stack Trace' required=false)
        public String stackTrace;

        @InvocableVariable(label='Class Name' required=true)
        public String className;

        @InvocableVariable(label='Method Name' required=false)
        public String methodName;

        @InvocableVariable(label='Additional Context' required=false)
        public String context;
    }

    @InvocableMethod(label='Report Error' description='Reports a caught exception to the triage webhook')
    public static void reportFromFlow(List<ErrorPayload> payloads) {
        for (ErrorPayload payload : payloads) {
            dispatch(payload.errorType, payload.errorMessage, payload.stackTrace, payload.className, payload.methodName, payload.context);
        }
    }

    public static void report(Exception e, String className, String methodName) {
        dispatch(e.getTypeName(), e.getMessage(), e.getStackTraceString(), className, methodName, null);
    }

    private static void dispatch(String errorType, String errorMessage, String stackTrace, String className, String methodName, String additionalContext) {
        Map<String, Object> payload = buildPayload(errorType, errorMessage, stackTrace, className, methodName, additionalContext);

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('ErrorCapture: webhook returned status ' + res.getStatusCode() + ' for ' + className);
        } catch (Exception dispatchError) {
            System.debug(LoggingLevel.ERROR, 'ErrorCapture: webhook callout failed - ' + dispatchError.getMessage());
        }
    }

    private static Map<String, Object> buildPayload(String errorType, String errorMessage, String stackTrace, String className, String methodName, String additionalContext) {
        Integer lineNumber = parseLineNumber(stackTrace);
        String sourceFile = 'force-app/main/default/classes/' + className + '.cls';
        String title = className + '.' + methodName + ' failed: ' + errorType;

        Map<String, Object> context = new Map<String, Object>{
            'module' => className,
            'action' => methodName,
            'inputs' => additionalContext
        };

        return new Map<String, Object>{
            'error_type' => errorType,
            'error_message' => errorMessage,
            'stack_trace' => stackTrace,
            'source_file' => sourceFile,
            'title' => title,
            'priority' => DEFAULT_PRIORITY,
            'context' => context,
            'repo_owner' => REPO_OWNER,
            'repo_name' => REPO_NAME,
            'app_name' => APP_NAME,
            'environment' => getEnvironment(),
            'timestamp' => System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''),
            'page_url' => Url.getOrgDomainUrl() != null ? Url.getOrgDomainUrl().toExternalForm() : '',
            'class_name' => className,
            'method_name' => methodName,
            'line_number' => lineNumber,
            'user_id' => UserInfo.getUserId(),
            'user_email' => UserInfo.getUserEmail(),
            'execution_context' => Request.getCurrent().getQuiddity().name(),
            'org_id' => UserInfo.getOrganizationId()
        };
    }

    private static String getEnvironment() {
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        return org.IsSandbox ? 'sandbox' : 'production';
    }

    private static Integer parseLineNumber(String stackTrace) {
        try {
            String firstLine = stackTrace.substringBefore('\n');
            String lineDigits = firstLine.substringAfter('line ').substringBefore(',');
            return Integer.valueOf(lineDigits);
        } catch (Exception parseError) {
            return null;
        }
    }
}