// Removes all demo data so you can re-run seed.apex before a recording.
// Run: sf apex run --file scripts/apex/reset.apex
delete [SELECT Id FROM Enrollment__c];
delete [SELECT Id FROM Program__c];
delete [SELECT Id FROM Contact WHERE Email LIKE '%@example.com'];
