public with sharing class GetProgramWaitlistAction {
    public class Request {
        @InvocableVariable(label='Program Name' description='Full or partial program name, for example Pre-K Morning' required=true)
        public String programName;
    }

    public class Response {
        @InvocableVariable(label='Waitlist' description='Seats held, pending offers with expiry, and the waitlist in queue order. Each line includes the Enrollment Id.')
        public String summary;
    }

    @InvocableMethod(label='Get Program Waitlist'
        description='Returns seats held versus capacity, pending offers with expiry times, and the ordered waitlist for one program.')
    public static List<Response> run(List<Request> requests) {
        List<Response> out = new List<Response>();
        // Agents send one request at a time; bulkify the lookup before reusing this from Flow at scale
        for (Request req : requests) {
            out.add(summarize(req.programName));
        }
        return out;
    }

    private static Response summarize(String programName) {
        Response r = new Response();
        String pattern = '%' + programName + '%';
        List<Program__c> matches = [SELECT Id, Name FROM Program__c WHERE Name LIKE :pattern WITH USER_MODE LIMIT 5];
        if (matches.size() != 1) {
            List<String> names = new List<String>();
            for (Program__c p : matches) {
                names.add(p.Name);
            }
            r.summary = matches.isEmpty()
                ? 'No program matches "' + programName + '".'
                : 'More than one program matches; ask which one: ' + String.join(names, ', ');
            return r;
        }

        EnrollmentController.Summary s = EnrollmentController.getSummary(matches[0].Id);
        List<String> lines = new List<String>{
            matches[0].Name + ': ' + s.seatsHeld + ' of ' + s.capacity + ' seats held.'
        };
        for (EnrollmentController.Row o : s.offered) {
            String expiry = o.offerExpiresAt == null ? 'no expiry set' : o.offerExpiresAt.format();
            lines.add('Offer pending: ' + o.contactName + ', expires ' + expiry + ' (Enrollment Id ' + o.id + ')');
        }
        for (EnrollmentController.Row w : s.waitlist) {
            lines.add('#' + w.position + ' ' + w.contactName + ' (Enrollment Id ' + w.id + ')');
        }
        if (s.waitlist.isEmpty()) {
            lines.add('Nobody is waiting.');
        }
        r.summary = String.join(lines, '\n');
        return r;
    }
}
