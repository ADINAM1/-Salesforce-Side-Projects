@IsTest
private class EnrollmentControllerTest {
    @IsTest
    static void summaryListsQueueInOrder() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(3);
        TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Enrolled');
        TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1], cs[2] }, 'Waitlisted');

        Test.startTest();
        EnrollmentController.Summary s = EnrollmentController.getSummary(p.Id);
        Test.stopTest();

        Assert.areEqual(1, s.capacity);
        Assert.areEqual(1, s.seatsHeld);
        Assert.areEqual(2, s.waitlist.size());
        Assert.areEqual(1, s.waitlist[0].position);
        Assert.areEqual('Test Family 001', s.waitlist[0].contactName);
    }

    @IsTest
    static void enrollAndChangeStatusSucceed() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(1);

        Test.startTest();
        EnrollmentController.enroll(p.Id, cs[0].Id);
        Enrollment__c e = [SELECT Id FROM Enrollment__c LIMIT 1];
        EnrollmentController.changeStatus(e.Id, 'Withdrawn');
        Test.stopTest();

        Assert.areEqual('Withdrawn', TestDataFactory.reload().get(e.Id).Status__c);
    }

    @IsTest
    static void controllerWrapsErrors() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(1);
        EnrollmentController.enroll(p.Id, cs[0].Id);

        try {
            EnrollmentController.enroll(p.Id, cs[0].Id);
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().contains('already'), ex.getMessage());
        }

        Enrollment__c e = [SELECT Id FROM Enrollment__c LIMIT 1];
        try {
            EnrollmentController.changeStatus(e.Id, 'Offered');
            Assert.fail('Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            Assert.isTrue(ex.getMessage().contains('Cannot move'), ex.getMessage());
        }
    }
}
