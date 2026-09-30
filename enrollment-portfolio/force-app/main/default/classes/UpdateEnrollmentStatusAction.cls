public with sharing class UpdateEnrollmentStatusAction {
    public class Request {
        @InvocableVariable(label='Contact Name' description='Name of the family contact on the enrollment' required=true)
        public String contactName;
        @InvocableVariable(label='Program Name' description='Full or partial program name' required=true)
        public String programName;
        @InvocableVariable(label='New Status' description='One of: Enrolled (accept an offer), Declined (decline an offer), Withdrawn (leave the program or waitlist)' required=true)
        public String newStatus;
    }

    public class Response {
        @InvocableVariable(label='Result' description='What changed, or why nothing changed')
        public String message;
    }

    @InvocableMethod(label='Update Enrollment Status'
        description='Accepts or declines a pending offer, or withdraws a family from a program or waitlist. A freed seat is offered to the next waitlisted family automatically.')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Response r = new Response();
            String contactPattern = '%' + req.contactName + '%';
            String programPattern = '%' + req.programName + '%';
            try {
                List<Enrollment__c> matches = [
                    SELECT Id, Status__c, Contact__r.Name, Program__r.Name FROM Enrollment__c
                    WHERE Contact__r.Name LIKE :contactPattern
                    AND Program__r.Name LIKE :programPattern
                    AND Status__c IN :EnrollmentService.ACTIVE
                    WITH USER_MODE LIMIT 5];
                if (matches.isEmpty()) {
                    r.message = 'No active enrollment found for ' + req.contactName + ' in ' + req.programName + '.';
                } else if (matches.size() > 1) {
                    r.message = 'Several enrollments match; ask the user for the full contact and program name.';
                } else {
                    Enrollment__c e = matches[0];
                    String priorStatus = e.Status__c;
                    EnrollmentService.changeStatus(e.Id, req.newStatus);
                    r.message = e.Contact__r.Name + ' moved from ' + priorStatus + ' to ' + req.newStatus
                        + ' in ' + e.Program__r.Name + ' (Enrollment Id ' + e.Id + ').';
                }
            } catch (EnrollmentService.EnrollmentException ex) {
                r.message = 'Not changed: ' + ex.getMessage();
            }
            out.add(r);
        }
        return out;
    }
}
