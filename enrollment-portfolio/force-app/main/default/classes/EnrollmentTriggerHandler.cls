public with sharing class EnrollmentTriggerHandler {
    @TestVisible
    private static Integer eventsPublished = 0;

    public static void run(System.TriggerOperation op, List<Enrollment__c> newList, Map<Id, Enrollment__c> oldMap) {
        Set<Id> freed = new Set<Id>();
        List<Enrollment_Change__e> events = new List<Enrollment_Change__e>();

        switch on op {
            when AFTER_INSERT {
                for (Enrollment__c e : newList) {
                    events.add(toEvent(e));
                }
            }
            when AFTER_UPDATE {
                for (Enrollment__c e : newList) {
                    Enrollment__c old = oldMap.get(e.Id);
                    if (e.Status__c == old.Status__c) {
                        continue;
                    }
                    events.add(toEvent(e));
                    if (EnrollmentService.SEAT_HOLDING.contains(old.Status__c)
                        && !EnrollmentService.SEAT_HOLDING.contains(e.Status__c)) {
                        freed.add(e.Program__c);
                    }
                }
            }
            when AFTER_DELETE {
                for (Enrollment__c old : oldMap.values()) {
                    if (EnrollmentService.SEAT_HOLDING.contains(old.Status__c)) {
                        freed.add(old.Program__c);
                    }
                }
            }
        }
        // fillOpenSeats only moves Waitlisted to Offered, which never frees a seat,
        // so the nested trigger run publishes events and stops. No recursion guard needed.
        if (!freed.isEmpty()) {
            EnrollmentService.fillOpenSeats(freed);
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
            eventsPublished += events.size();
        }
    }

    private static Enrollment_Change__e toEvent(Enrollment__c e) {
        return new Enrollment_Change__e(
            Enrollment_Id__c = e.Id,
            Program_Id__c = e.Program__c,
            Contact_Id__c = e.Contact__c,
            New_Status__c = e.Status__c
        );
    }
}
