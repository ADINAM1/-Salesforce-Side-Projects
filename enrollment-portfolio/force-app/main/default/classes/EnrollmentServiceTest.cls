@IsTest
private class EnrollmentServiceTest {
    @IsTest
    static void enrollUnderCapacityIsEnrolled() {
        Program__c p = TestDataFactory.program(2);
        List<Contact> cs = TestDataFactory.contacts(1);

        Test.startTest();
        Enrollment__c e = EnrollmentService.enroll(p.Id, cs[0].Id);
        Test.stopTest();

        Assert.areEqual('Enrolled', TestDataFactory.reload().get(e.Id).Status__c);
    }

    @IsTest
    static void enrollAtCapacityIsWaitlisted() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(2);
        EnrollmentService.enroll(p.Id, cs[0].Id);

        Test.startTest();
        Enrollment__c second = EnrollmentService.enroll(p.Id, cs[1].Id);
        Test.stopTest();

        Assert.areEqual('Waitlisted', TestDataFactory.reload().get(second.Id).Status__c);
    }

    @IsTest
    static void duplicateEnrollmentIsRejected() {
        Program__c p = TestDataFactory.program(5);
        List<Contact> cs = TestDataFactory.contacts(1);
        EnrollmentService.enroll(p.Id, cs[0].Id);

        try {
            EnrollmentService.enroll(p.Id, cs[0].Id);
            Assert.fail('Expected a duplicate enrollment error');
        } catch (EnrollmentService.EnrollmentException ex) {
            Assert.isTrue(ex.getMessage().contains('already'), ex.getMessage());
        }
    }

    @IsTest
    static void invalidTransitionIsRejected() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(1);
        Enrollment__c w = TestDataFactory.enrollments(p.Id, cs, 'Waitlisted')[0];

        try {
            EnrollmentService.changeStatus(w.Id, 'Enrolled');
            Assert.fail('Waitlisted to Enrolled should be rejected');
        } catch (EnrollmentService.EnrollmentException ex) {
            Assert.isTrue(ex.getMessage().contains('Cannot move'), ex.getMessage());
        }
    }

    @IsTest
    static void withdrawalOffersSeatToOldestWaitlisted() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(3);
        Enrollment__c firstEnrollment = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Enrolled')[0];
        List<Enrollment__c> waiting = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1], cs[2] }, 'Waitlisted');

        Test.startTest();
        EnrollmentService.changeStatus(firstEnrollment.Id, 'Withdrawn');
        Test.stopTest();

        Map<Id, Enrollment__c> result = TestDataFactory.reload();
        Assert.areEqual('Withdrawn', result.get(firstEnrollment.Id).Status__c);
        Assert.areEqual('Offered', result.get(waiting[0].Id).Status__c, 'Oldest waitlisted family gets the seat');
        Assert.isNotNull(result.get(waiting[0].Id).Offer_Expires_At__c, 'Offer has an expiry');
        Assert.areEqual('Waitlisted', result.get(waiting[1].Id).Status__c, 'Next family keeps waiting');
    }

    @IsTest
    static void acceptingOfferEnrolls() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(1);
        Enrollment__c offer = TestDataFactory.enrollments(p.Id, cs, 'Offered')[0];

        Test.startTest();
        EnrollmentService.changeStatus(offer.Id, 'Enrolled');
        Test.stopTest();

        Enrollment__c result = TestDataFactory.reload().get(offer.Id);
        Assert.areEqual('Enrolled', result.Status__c);
        Assert.isNotNull(result.Enrolled_At__c);
    }

    @IsTest
    static void capacityIncreaseOffersMultipleSeats() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(4);
        TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Enrolled');
        List<Enrollment__c> waiting = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1], cs[2], cs[3] }, 'Waitlisted');

        Test.startTest();
        p.Capacity__c = 3;
        update p;
        Test.stopTest();

        Map<Id, Enrollment__c> result = TestDataFactory.reload();
        Assert.areEqual('Offered', result.get(waiting[0].Id).Status__c);
        Assert.areEqual('Offered', result.get(waiting[1].Id).Status__c);
        Assert.areEqual('Waitlisted', result.get(waiting[2].Id).Status__c);
    }

    @IsTest
    static void deletingEnrollmentFreesSeat() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(2);
        Enrollment__c firstEnrollment = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Enrolled')[0];
        Enrollment__c nextFamily = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1] }, 'Waitlisted')[0];

        Test.startTest();
        delete firstEnrollment;
        Test.stopTest();

        Assert.areEqual('Offered', TestDataFactory.reload().get(nextFamily.Id).Status__c);
    }

    @IsTest
    static void expiredOfferPromotesNextFamily() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(2);
        Enrollment__c offer = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[0] }, 'Offered')[0];
        Enrollment__c nextFamily = TestDataFactory.enrollments(p.Id, new List<Contact>{ cs[1] }, 'Waitlisted')[0];
        offer.Offer_Expires_At__c = System.now().addHours(-1);
        update offer;

        Test.startTest();
        Database.executeBatch(new OfferExpirationJob(), 200);
        Test.stopTest();

        Map<Id, Enrollment__c> result = TestDataFactory.reload();
        Assert.areEqual('Expired', result.get(offer.Id).Status__c);
        Assert.areEqual('Offered', result.get(nextFamily.Id).Status__c);
    }

    @IsTest
    static void bulkWithdrawal200() {
        Program__c p = TestDataFactory.program(200);
        List<Contact> cs = TestDataFactory.contacts(250);
        List<Contact> enrolledContacts = new List<Contact>();
        List<Contact> waitingContacts = new List<Contact>();
        for (Integer i = 0; i < cs.size(); i++) {
            if (i < 200) {
                enrolledContacts.add(cs[i]);
            } else {
                waitingContacts.add(cs[i]);
            }
        }
        List<Enrollment__c> enrolled = TestDataFactory.enrollments(p.Id, enrolledContacts, 'Enrolled');
        TestDataFactory.enrollments(p.Id, waitingContacts, 'Waitlisted');

        Test.startTest();
        for (Enrollment__c e : enrolled) {
            e.Status__c = 'Withdrawn';
        }
        update enrolled;
        Test.stopTest();

        Integer offered = [SELECT COUNT() FROM Enrollment__c WHERE Status__c = 'Offered'];
        Assert.areEqual(50, offered, 'All 50 waitlisted families are offered seats in one transaction');
    }

    @IsTest
    static void statusChangePublishesEvent() {
        Program__c p = TestDataFactory.program(1);
        List<Contact> cs = TestDataFactory.contacts(1);
        Integer eventsBefore = EnrollmentTriggerHandler.eventsPublished;

        Test.startTest();
        EnrollmentService.enroll(p.Id, cs[0].Id);
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.areEqual(eventsBefore + 1, EnrollmentTriggerHandler.eventsPublished);
    }

    @IsTest
    static void scheduleJobRegistersCron() {
        Test.startTest();
        String jobId = System.schedule('Offer expiry test', '0 0 * * * ?', new OfferExpirationJob());
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
    }
}
