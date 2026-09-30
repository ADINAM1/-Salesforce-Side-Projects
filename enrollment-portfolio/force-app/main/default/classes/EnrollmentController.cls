public with sharing class EnrollmentController {
    public class Row {
        @AuraEnabled public Id id;
        @AuraEnabled public String contactName;
        @AuraEnabled public String status;
        @AuraEnabled public Integer position;
        @AuraEnabled public Datetime offerExpiresAt;
    }

    public class Summary {
        @AuraEnabled public Integer capacity;
        @AuraEnabled public Integer seatsHeld;
        @AuraEnabled public List<Row> enrolled = new List<Row>();
        @AuraEnabled public List<Row> offered = new List<Row>();
        @AuraEnabled public List<Row> waitlist = new List<Row>();
    }

    @AuraEnabled(cacheable=true)
    public static Summary getSummary(Id programId) {
        Program__c p = [SELECT Capacity__c FROM Program__c WHERE Id = :programId WITH USER_MODE];
        Summary s = new Summary();
        s.capacity = p.Capacity__c.intValue();
        Integer position = 0;
        for (Enrollment__c e : [SELECT Id, Contact__r.Name, Status__c, Offer_Expires_At__c
                                FROM Enrollment__c
                                WHERE Program__c = :programId AND Status__c IN :EnrollmentService.ACTIVE
                                WITH USER_MODE
                                ORDER BY Waitlisted_At__c ASC NULLS LAST, Enrolled_At__c ASC, Name ASC]) {
            Row r = new Row();
            r.id = e.Id;
            r.contactName = e.Contact__r.Name;
            r.status = e.Status__c;
            r.offerExpiresAt = e.Offer_Expires_At__c;
            if (e.Status__c == 'Waitlisted') {
                position++;
                r.position = position;
                s.waitlist.add(r);
            } else if (e.Status__c == 'Offered') {
                s.offered.add(r);
            } else {
                s.enrolled.add(r);
            }
        }
        s.seatsHeld = s.enrolled.size() + s.offered.size();
        return s;
    }

    @AuraEnabled
    public static void enroll(Id programId, Id contactId) {
        try {
            EnrollmentService.enroll(programId, contactId);
        } catch (EnrollmentService.EnrollmentException ex) {
            throw auraError(ex.getMessage());
        }
    }

    @AuraEnabled
    public static void changeStatus(Id enrollmentId, String newStatus) {
        try {
            EnrollmentService.changeStatus(enrollmentId, newStatus);
        } catch (EnrollmentService.EnrollmentException ex) {
            throw auraError(ex.getMessage());
        }
    }

    private static AuraHandledException auraError(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg); // makes the message assertable in tests
        return e;
    }
}
