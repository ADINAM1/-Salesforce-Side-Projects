trigger EnrollmentTrigger on Enrollment__c (after insert, after update, after delete) {
    EnrollmentTriggerHandler.run(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
