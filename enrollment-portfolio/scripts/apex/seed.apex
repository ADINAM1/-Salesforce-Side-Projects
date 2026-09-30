// Demo data for the enrollment portfolio.
// Run: sf apex run --file scripts/apex/seed.apex
// Tip: change the email domain below to your own address (plus-addressing works)
// so the notification emails from the Flow land in your inbox.
String emailDomain = 'example.com';

Map<String, Integer> capacities = new Map<String, Integer>{
    'Pre-K Morning' => 3,
    'Pre-K Afternoon' => 5,
    'Infant Care' => 4,
    'Toddler Play' => 6
};
Map<String, List<String>> families = new Map<String, List<String>>{
    'Pre-K Morning' => new List<String>{ 'Wei Chen', 'Aisha Khan', 'Liam Walsh', 'Priya Patel', 'Noah Kim', 'Sofia Rossi' },
    'Pre-K Afternoon' => new List<String>{ 'Ethan Brooks', 'Mia Nguyen', 'Lucas Silva', 'Zara Ali' },
    'Infant Care' => new List<String>{ 'Olivia Reed', 'James Park', 'Ava Johnson', 'Mateo Garcia', 'Maria Lopez', 'Hana Sato', 'Leo Novak' },
    'Toddler Play' => new List<String>{ 'Emma Davis', 'Omar Haddad', 'Chloe Martin', 'Ryan Cooper', 'Nia Brown', 'Jack Wilson', 'Isla Moore' }
};

Map<String, Program__c> programsByName = new Map<String, Program__c>();
for (String programName : capacities.keySet()) {
    programsByName.put(programName, new Program__c(
        Name = programName,
        Capacity__c = capacities.get(programName),
        Offer_Window_Hours__c = 48,
        Start_Date__c = Date.today().addDays(14)
    ));
}
insert programsByName.values();

Map<String, Contact> contactsByName = new Map<String, Contact>();
for (List<String> fullNames : families.values()) {
    for (String fullName : fullNames) {
        List<String> parts = fullName.split(' ');
        contactsByName.put(fullName, new Contact(
            FirstName = parts[0],
            LastName = parts[1],
            Email = parts[0].toLowerCase() + '.' + parts[1].toLowerCase() + '@' + emailDomain
        ));
    }
}
insert contactsByName.values();

// Enroll through the service so capacity and waitlist rules apply
Map<String, Enrollment__c> enrollmentsByKey = new Map<String, Enrollment__c>();
for (String programName : families.keySet()) {
    for (String fullName : families.get(programName)) {
        Enrollment__c e = EnrollmentService.enroll(programsByName.get(programName).Id, contactsByName.get(fullName).Id);
        enrollmentsByKey.put(programName + '|' + fullName, e);
    }
}

// Free one Infant Care seat so Maria Lopez (waitlist #1) receives an offer
EnrollmentService.changeStatus(enrollmentsByKey.get('Infant Care|Mateo Garcia').Id, 'Withdrawn');

System.debug('Seeded ' + programsByName.size() + ' programs and ' + contactsByName.size() + ' contacts.');
