@IsTest
private class AgentActionsTest {
    @IsTest
    static void findProgramsWithOpenings() {
        Program__c openProgram = TestDataFactory.program('Infant Care', 3);
        Program__c fullProgram = TestDataFactory.program('Toddler Play', 1);
        List<Contact> cs = TestDataFactory.contacts(2);
        TestDataFactory.enrollments(openProgram.Id, new List<Contact>{ cs[0] }, 'Enrolled');
        TestDataFactory.enrollments(fullProgram.Id, new List<Contact>{ cs[1] }, 'Enrolled');

        FindProgramsWithOpeningsAction.Request anySeats = new FindProgramsWithOpeningsAction.Request();
        FindProgramsWithOpeningsAction.Request many = new FindProgramsWithOpeningsAction.Request();
        many.minSeats = 5;

        Test.startTest();
        List<FindProgramsWithOpeningsAction.Response> out =
            FindProgramsWithOpeningsAction.run(new List<FindProgramsWithOpeningsAction.Request>{ anySeats, many });
        Test.stopTest();

        Assert.isTrue(out[0].summary.contains('Infant Care: 2 open seat(s)'), out[0].summary);
        Assert.isFalse(out[0].summary.contains('Toddler Play'), out[0].summary);
        Assert.isTrue(out[1].summary.startsWith('No programs'), out[1].summary);
    }

    @IsTest
    static void waitlistSummaryAndAmbiguity() {
        Program__c morning = TestDataFactory.program('Pre-K Morning', 1);
        TestDataFactory.program('Pre-K Afternoon', 5);
        List<Contact> cs = TestDataFactory.contacts(3);
        TestDataFactory.enrollments(morning.Id, new List<Contact>{ cs[0] }, 'Offered');
        TestDataFactory.enrollments(morning.Id, new List<Contact>{ cs[1], cs[2] }, 'Waitlisted');

        List<GetProgramWaitlistAction.Request> reqs = new List<GetProgramWaitlistAction.Request>();
        for (String name : new List<String>{ 'Pre-K Morning', 'Pre-K', 'Swimming' }) {
            GetProgramWaitlistAction.Request r = new GetProgramWaitlistAction.Request();
            r.programName = name;
            reqs.add(r);
        }

        Test.startTest();
        List<GetProgramWaitlistAction.Response> out = GetProgramWaitlistAction.run(reqs);
        Test.stopTest();

        Assert.isTrue(out[0].summary.contains('#1 Test Family 001'), out[0].summary);
        Assert.isTrue(out[0].summary.contains('Offer pending: Test Family 000'), out[0].summary);
        Assert.isTrue(out[1].summary.startsWith('More than one program matches'), out[1].summary);
        Assert.isTrue(out[2].summary.startsWith('No program matches'), out[2].summary);
    }

    @IsTest
    static void updateStatusOutcomes() {
        Program__c p = TestDataFactory.program('Infant Care', 1);
        List<Contact> cs = TestDataFactory.contacts(3);
        TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Offered');
        TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1], cs[2] }, 'Waitlisted');

        List<UpdateEnrollmentStatusAction.Request> reqs = new List<UpdateEnrollmentStatusAction.Request>{
            req('Test Family 000', 'Infant Care', 'Enrolled'),   // accept offer
            req('Test Family 001', 'Infant Care', 'Enrolled'),   // invalid: waitlisted straight to enrolled
            req('Nobody Here', 'Infant Care', 'Withdrawn'),      // not found
            req('Test Family 00', 'Infant Care', 'Withdrawn')    // ambiguous
        };

        Test.startTest();
        List<UpdateEnrollmentStatusAction.Response> out = UpdateEnrollmentStatusAction.run(reqs);
        Test.stopTest();

        Assert.isTrue(out[0].message.contains('moved from Offered to Enrolled'), out[0].message);
        Assert.isTrue(out[1].message.startsWith('Not changed'), out[1].message);
        Assert.isTrue(out[2].message.startsWith('No active enrollment'), out[2].message);
        Assert.isTrue(out[3].message.startsWith('Several enrollments match'), out[3].message);
    }

    private static UpdateEnrollmentStatusAction.Request req(String contactName, String programName, String status) {
        UpdateEnrollmentStatusAction.Request r = new UpdateEnrollmentStatusAction.Request();
        r.contactName = contactName;
        r.programName = programName;
        r.newStatus = status;
        return r;
    }
}
