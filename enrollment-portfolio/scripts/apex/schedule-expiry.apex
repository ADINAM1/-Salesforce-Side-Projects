// Schedules the hourly offer-expiration job.
// Run: sf apex run --file scripts/apex/schedule-expiry.apex
System.schedule('Expire enrollment offers hourly', '0 0 * * * ?', new OfferExpirationJob());
