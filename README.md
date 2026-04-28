# Salesforce Report Organizer

Automatically moves Salesforce reports into designated folders based on report ownership. Runs daily at midnight via scheduled Apex.

## How It Works

1. `ReportOrganizerScheduler` fires every night at midnight
2. It triggers `ReportOrganizerBatch` which queries all reports owned by configured users
3. For each report, it calls the Analytics REST API to move it to the mapped folder
4. A completion email is sent to the running user when done

## Setup

### 1. Create target folders

Create report folders manually in Salesforce UI under **Reports > New Folder**. Note the Folder IDs.

### 2. Get User and Folder IDs

Run these in Developer Console > Query Editor:

```sql
SELECT Id, Name FROM User WHERE IsActive = true

SELECT Id, Name, DeveloperName FROM Folder WHERE Type = 'Report'
```

### 3. Update the mapping

Open `ReportOrganizerBatch` and update `OWNER_TO_FOLDER`:

```apex
private static final Map<Id, String> OWNER_TO_FOLDER = new Map<Id, String>{
    '005d200000HqWV3AAN' => '00ld200000GgPs1AAF'
};
```

### 4. Add Remote Site Setting

Go to **Setup > Remote Site Settings > New**:

- Name: `SelfOrg`
- URL: your org base URL (e.g. `https://yourorg.my.salesforce.com`)

### 5. Deploy Apex classes

Deploy both classes via change set, SFDX, or Developer Console:

- `ReportOrganizerBatch.cls`
- `ReportOrganizerScheduler.cls`

### 6. Schedule the job

Run once from Execute Anonymous:

```apex
System.schedule('Daily Report Organizer', '0 0 0 * * ?', new ReportOrganizerScheduler());
```

Verify under **Setup > Scheduled Jobs**.

### 7. Test manually

```apex
Database.executeBatch(new ReportOrganizerBatch(), 5);
```

Check debug logs for `Report moved successfully` and verify in the Reports tab.

## Files

```
├── force-app/main/default/classes/
│   ├── ReportOrganizerBatch.cls
│   ├── ReportOrganizerBatch.cls-meta.xml
│   ├── ReportOrganizerScheduler.cls
│   └── ReportOrganizerScheduler.cls-meta.xml
└── README.md
```

## Extending to Other Use Cases

| Use Case | Change Required |
|---|---|
| Move dashboards by owner | Query `Dashboard` object, same PATCH endpoint under `/analytics/dashboards/` |
| Reassign reports on user deactivation | Change PATCH body to `ownerId` instead of `folderId` |
| Archive reports unused for 6 months | Add `WHERE LastRunDate < LAST_N_MONTHS:6` to SOQL |
| Move reports by name pattern | Add `WHERE Name LIKE '%Finance%'` to SOQL |

## API

Report folder assignment uses the Analytics REST API, not SOQL or the Tooling API.

```
PATCH /services/data/v59.0/analytics/reports/{reportId}
Body: {"reportMetadata": {"folderId": "<targetFolderId>"}}
```

## Limits

| Limit | Value | Notes |
|---|---|---|
| Callouts per transaction | 100 | Batch size of 5 keeps this safe |
| Scheduled jobs per org | 100 | One job used |
| Emails per day | 1,000 | One email sent per batch run |
