/**
 * @description Scheduler that invokes ReportOrganizerBatch on a recurring basis.
 *              By default, scheduled to run daily at midnight via System.schedule.
 *
 *              To schedule manually, run the following from Execute Anonymous:
 *                  System.schedule('Daily Report Organizer', '0 0 0 * * ?', new ReportOrganizerScheduler());
 *
 * @see         ReportOrganizerBatch
 */
public class ReportOrganizerScheduler implements Schedulable {

    /**
     * @description Batch size of 5 ensures callout limits are respected
     *              within a single transaction (platform max: 100 callouts).
     */
    private static final Integer BATCH_SIZE = 5;

    /**
     * @description Entry point invoked by the Salesforce scheduler.
     *              Kicks off the report organizer batch job.
     *
     * @param sc    Schedulable context provided by the platform
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ReportOrganizerBatch(), BATCH_SIZE);
    }
}
