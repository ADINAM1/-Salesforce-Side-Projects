/**
 * Expires offers past their deadline. The trigger then offers each freed seat
 * to the next waitlisted family. Schedule hourly:
 * System.schedule('Expire enrollment offers hourly', '0 0 * * * ?', new OfferExpirationJob());
 */
public with sharing class OfferExpirationJob implements Database.Batchable<SObject>, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime now = System.now();
        return Database.getQueryLocator([
            SELECT Id FROM Enrollment__c
            WHERE Status__c = 'Offered' AND Offer_Expires_At__c < :now
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Enrollment__c> scope) {
        for (Enrollment__c e : scope) {
            e.Status__c = 'Expired';
        }
        update scope;
    }

    public void finish(Database.BatchableContext bc) {
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new OfferExpirationJob(), 200);
    }
}
