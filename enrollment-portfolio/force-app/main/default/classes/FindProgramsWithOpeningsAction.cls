public with sharing class FindProgramsWithOpeningsAction {
    public class Request {
        @InvocableVariable(label='Minimum Seats' description='Only return programs with at least this many open seats. Defaults to 1.')
        public Integer minSeats;
    }

    public class Response {
        @InvocableVariable(label='Programs Summary' description='One line per program: name, open seats, families waiting.')
        public String summary;
    }

    @InvocableMethod(label='Find Programs With Openings'
        description='Lists programs that currently have open seats, with the number of open seats and waitlisted families.')
    public static List<Response> run(List<Request> requests) {
        Map<Id, Integer> waiting = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Program__c programId, COUNT(Id) total FROM Enrollment__c
                                   WHERE Status__c = 'Waitlisted' WITH USER_MODE GROUP BY Program__c]) {
            waiting.put((Id) ar.get('programId'), (Integer) ar.get('total'));
        }
        List<Program__c> programs = [SELECT Id, Name, Capacity__c, Seats_Held__c FROM Program__c
                                     WITH USER_MODE ORDER BY Name];

        List<Response> out = new List<Response>();
        for (Request req : requests) {
            Integer minSeats = (req == null || req.minSeats == null || req.minSeats < 1) ? 1 : req.minSeats;
            List<String> lines = new List<String>();
            for (Program__c p : programs) {
                Integer heldSeats = p.Seats_Held__c == null ? 0 : p.Seats_Held__c.intValue();
                Integer openSeats = p.Capacity__c.intValue() - heldSeats;
                if (openSeats >= minSeats) {
                    Integer w = waiting.containsKey(p.Id) ? waiting.get(p.Id) : 0;
                    lines.add(p.Name + ': ' + openSeats + ' open seat(s), ' + w + ' waiting');
                }
            }
            Response r = new Response();
            r.summary = lines.isEmpty()
                ? 'No programs currently have ' + minSeats + ' or more open seats.'
                : String.join(lines, '\n');
            out.add(r);
        }
        return out;
    }
}
