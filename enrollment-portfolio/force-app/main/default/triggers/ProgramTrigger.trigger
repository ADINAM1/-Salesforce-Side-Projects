trigger ProgramTrigger on Program__c (after update) {
    Set<Id> grew = new Set<Id>();
    for (Program__c p : Trigger.new) {
        if (p.Capacity__c > Trigger.oldMap.get(p.Id).Capacity__c) {
            grew.add(p.Id);
        }
    }
    if (!grew.isEmpty()) {
        EnrollmentService.fillOpenSeats(grew);
    }
}
