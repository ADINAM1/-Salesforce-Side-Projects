/**
 * All enrollment rules live here. The trigger, LWC controller, batch job
 * and Agentforce actions call these methods and nothing else writes status.
 */
public with sharing class EnrollmentService {
    public class EnrollmentException extends Exception {}

    public static final Set<String> SEAT_HOLDING = new Set<String>{ 'Enrolled', 'Offered' };
    public static final Set<String> ACTIVE = new Set<String>{ 'Enrolled', 'Offered', 'Waitlisted' };

    // Allowed status moves; anything else is rejected
    private static final Map<String, Set<String>> TRANSITIONS = new Map<String, Set<String>>{
        'Waitlisted' => new Set<String>{ 'Withdrawn' },
        'Offered'    => new Set<String>{ 'Enrolled', 'Declined', 'Expired' },
        'Enrolled'   => new Set<String>{ 'Withdrawn' }
    };

    public static Enrollment__c enroll(Id programId, Id contactId) {
        // Lock the program row so two coordinators cannot take the last seat at once
        Program__c program = [SELECT Id, Capacity__c FROM Program__c WHERE Id = :programId FOR UPDATE];

        Integer duplicates = [SELECT COUNT() FROM Enrollment__c
                              WHERE Program__c = :programId AND Contact__c = :contactId
                              AND Status__c IN :ACTIVE];
        if (duplicates > 0) {
            throw new EnrollmentException('This contact already has an active enrollment in this program.');
        }

        Integer held = [SELECT COUNT() FROM Enrollment__c
                        WHERE Program__c = :programId AND Status__c IN :SEAT_HOLDING];

        Enrollment__c e = new Enrollment__c(Program__c = programId, Contact__c = contactId);
        if (held < program.Capacity__c) {
            e.Status__c = 'Enrolled';
            e.Enrolled_At__c = System.now();
        } else {
            e.Status__c = 'Waitlisted';
            e.Waitlisted_At__c = System.now();
        }
        insert e;
        return e;
    }

    public static void changeStatus(Id enrollmentId, String newStatus) {
        Enrollment__c e = [SELECT Id, Status__c FROM Enrollment__c WHERE Id = :enrollmentId FOR UPDATE];
        Set<String> allowed = TRANSITIONS.get(e.Status__c);
        if (allowed == null || !allowed.contains(newStatus)) {
            throw new EnrollmentException('Cannot move an enrollment from ' + e.Status__c + ' to ' + newStatus + '.');
        }
        e.Status__c = newStatus;
        if (newStatus == 'Enrolled') {
            e.Enrolled_At__c = System.now();
        }
        update e; // the trigger handles any freed seat
    }

    public static void fillOpenSeats(Set<Id> programIds) {
        // SOQL does not allow ORDER BY in a locking query, so lock programs first
        Map<Id, Program__c> programs = new Map<Id, Program__c>([
            SELECT Id, Capacity__c, Offer_Window_Hours__c FROM Program__c
            WHERE Id IN :programIds FOR UPDATE
        ]);

        Map<Id, Integer> held = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Program__c programId, COUNT(Id) total FROM Enrollment__c
                                   WHERE Program__c IN :programIds AND Status__c IN :SEAT_HOLDING
                                   GROUP BY Program__c]) {
            held.put((Id) ar.get('programId'), (Integer) ar.get('total'));
        }

        Datetime now = System.now();
        List<Enrollment__c> offers = new List<Enrollment__c>();
        // Name (auto number) breaks ties when several families joined in the same millisecond
        for (Enrollment__c w : [SELECT Id, Program__c FROM Enrollment__c
                                WHERE Program__c IN :programIds AND Status__c = 'Waitlisted'
                                ORDER BY Program__c, Waitlisted_At__c ASC, Name ASC]) {
            Program__c p = programs.get(w.Program__c);
            if (p == null) {
                continue;
            }
            Integer seatsHeld = held.containsKey(p.Id) ? held.get(p.Id) : 0;
            if (seatsHeld < p.Capacity__c) {
                Integer hours = p.Offer_Window_Hours__c == null ? 48 : p.Offer_Window_Hours__c.intValue();
                w.Status__c = 'Offered';
                w.Offered_At__c = now;
                w.Offer_Expires_At__c = now.addHours(hours);
                held.put(p.Id, seatsHeld + 1);
                offers.add(w);
            }
        }
        if (!offers.isEmpty()) {
            update offers;
        }
    }
}
