/**
 * AccountEnrichmentService
 *
 * Enriches Account records with primary Contact details.
 * DEMO NOTE: Contains 3 intentional bugs for the Issue Triage Agent showcase.
 *
 * BUG 1 — SOQL inside for loop (line 44)
 *   Impact : Governor LimitException once accountIds list exceeds ~100 records
 *   Trigger: Call enrichAccountsWithContactData() with a large list
 *
 * BUG 2 — List index out of bounds (line 48)
 *   Impact : ListException: List index out of bounds: 0
 *   Trigger: Call with an Account that has zero Contacts
 *
 * BUG 3 — Null pointer dereference (line 52)
 *   Impact : System.NullPointerException
 *   Trigger: Call with a Contact whose Email field is null
 */
public class AccountEnrichmentService {

    /**
     * Called by accountDashboard LWC via @wire.
     * Returns a single Account with its first Contact sub-query.
     */
    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(Id accountId) {
        return [
            SELECT Id, Name, AnnualRevenue, Phone,
                   (SELECT Id, Name, Email FROM Contacts LIMIT 1)
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }

    /**
     * Called by accountEnrichmentPanel LWC to populate the enrichment table.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccountsForEnrichment() {
        return [
            SELECT Id, Name, Phone, AnnualRevenue
            FROM Account
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    /**
     * Bulk enrichment — reads Contact data and stamps it onto each Account.
     * INTENTIONALLY BROKEN for demo purposes. Do not use in production.
     */
    @AuraEnabled
    public static void enrichAccountsWithContactData(List<Id> accountIds) {
        try {
            List<Account> accounts = [
                SELECT Id, Name, Phone, Description
                FROM Account
                WHERE Id IN :accountIds
            ];

            List<Account> toUpdate = new List<Account>();

            for (Account acc : accounts) {
                // BUG 1: SOQL inside for loop — fires a query on every iteration
                List<Contact> contacts = [
                    SELECT Id, Email, Phone
                    FROM Contact
                    WHERE AccountId = :acc.Id
                    LIMIT 1
                ];

                // BUG 2: No list-size check — throws ListException when account has no contacts
                Contact primary = contacts[0];

                // BUG 3: Null dereference — throws NullPointerException when Email is null
                acc.Description = 'Primary contact: ' + primary.Email.toLowerCase();
                acc.Phone = primary.Phone;
                toUpdate.add(acc);
            }

            update toUpdate;
        }
        catch (Exception e) {
            ErrorCapture.report(e, 'AccountEnrichmentService', 'enrichAccountsWithContactData');

            String friendlyMessage = e.getTypeName() + ' - ' + e.getMessage();
            AuraHandledException authEx = new AuraHandledException(friendlyMessage);
            authEx.setMessage(friendlyMessage);
            throw authEx;
        }
    }
}