/**
 * @description Batch job that moves Salesforce reports to designated folders
 *              based on report ownership. Uses the Analytics REST API to
 *              perform folder assignments programmatically.
 *
 */
public class ReportOrganizerBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /**
     * @description Maps each report owner's User ID to their designated folder ID.
     *              Add or remove entries as ownership requirements change.
     */
    private static final Map<Id, String> OWNER_TO_FOLDER = new Map<Id, String>{
        '005d200000HqWV3AAN' => '00ld200000GgPs1AAF'
    };

    private static final String API_VERSION = 'v59.0';

    /**
     * @description Returns a QueryLocator scoped to reports owned by users
     *              defined in the OWNER_TO_FOLDER mapping.
     *
     * @param bc    Batchable context provided by the platform
     * @return      QueryLocator of matching Report records
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Id> ownerIds = OWNER_TO_FOLDER.keySet();
        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId
            FROM Report
            WHERE OwnerId IN :ownerIds
        ]);
    }

    /**
     * @description Processes each batch of reports and moves them to the
     *              appropriate folder via the Analytics REST API.
     *
     * @param bc      Batchable context provided by the platform
     * @param reports Chunk of Report records to process in this execution
     */
    public void execute(Database.BatchableContext bc, List<Report> reports) {
        String baseUrl   = URL.getOrgDomainUrl().toExternalForm();
        String sessionId = UserInfo.getSessionId();

        for (Report r : reports) {
            String targetFolderId = OWNER_TO_FOLDER.get(r.OwnerId);

            if (String.isBlank(targetFolderId)) {
                System.debug(LoggingLevel.WARN, 'No folder mapping found for owner ' + r.OwnerId + '. Skipping report: ' + r.Name);
                continue;
            }

            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(baseUrl + '/services/data/' + API_VERSION + '/analytics/reports/' + r.Id);
                req.setMethod('PATCH');
                req.setHeader('Authorization', 'Bearer ' + sessionId);
                req.setHeader('Content-Type', 'application/json');
                req.setBody('{"reportMetadata": {"folderId": "' + targetFolderId + '"}}');
                req.setTimeout(60000);

                HttpResponse res = new Http().send(req);

                if (res.getStatusCode() == 200) {
                    System.debug(LoggingLevel.INFO, 'Report moved successfully: ' + r.Name + ' -> ' + targetFolderId);
                } else {
                    System.debug(LoggingLevel.ERROR, 'Failed to move report: ' + r.Name + ' | HTTP ' + res.getStatusCode() + ' | ' + res.getBody());
                }

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Exception while moving report ' + r.Name + ': ' + e.getMessage());
            }
        }
    }

    /**
     * @description Sends a completion summary email to the running user
     *              once all batch executions have finished.
     *
     * @param bc    Batchable context provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, TotalJobItems, CreatedDate
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
        mail.setSubject('Report Organizer Batch — ' + job.Status);
        mail.setPlainTextBody(
            'Report Organizer Batch completed.\n\n' +
            'Status        : ' + job.Status + '\n' +
            'Total Batches : ' + job.TotalJobItems + '\n' +
            'Errors        : ' + job.NumberOfErrors + '\n' +
            'Completed At  : ' + DateTime.now().format() + '\n\n' +
            'Log in to Salesforce to verify report folder assignments.'
        );

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }
}
