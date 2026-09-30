@IsTest
public class TestDataFactory {
    public static Program__c program(Integer capacity) {
        return program('Test Program', capacity);
    }

    public static Program__c program(String name, Integer capacity) {
        Program__c p = new Program__c(Name = name, Capacity__c = capacity, Offer_Window_Hours__c = 48);
        insert p;
        return p;
    }

    public static List<Contact> contacts(Integer n) {
        List<Contact> cs = new List<Contact>();
        for (Integer i = 0; i < n; i++) {
            String suffix = String.valueOf(i).leftPad(3, '0');
            cs.add(new Contact(LastName = 'Test Family ' + suffix, Email = 'family' + suffix + '@example.com'));
        }
        insert cs;
        return cs;
    }

    /** Inserts enrollments directly (bypassing the service) with distinct, ordered timestamps. */
    public static List<Enrollment__c> enrollments(Id programId, List<Contact> cs, String status) {
        Datetime base = System.now().addHours(-1);
        List<Enrollment__c> rows = new List<Enrollment__c>();
        for (Integer i = 0; i < cs.size(); i++) {
            Enrollment__c e = new Enrollment__c(Program__c = programId, Contact__c = cs[i].Id, Status__c = status);
            if (status == 'Waitlisted') {
                e.Waitlisted_At__c = base.addSeconds(i);
            } else if (status == 'Enrolled') {
                e.Enrolled_At__c = base.addSeconds(i);
            } else if (status == 'Offered') {
                e.Offered_At__c = base;
                e.Offer_Expires_At__c = base.addHours(48);
            }
            rows.add(e);
        }
        insert rows;
        return rows;
    }

    public static Map<Id, Enrollment__c> reload() {
        return new Map<Id, Enrollment__c>([
            SELECT Id, Status__c, Offer_Expires_At__c, Enrolled_At__c FROM Enrollment__c
        ]);
    }
}
