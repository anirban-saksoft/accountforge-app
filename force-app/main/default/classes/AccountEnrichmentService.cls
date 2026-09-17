/**
 * AccountEnrichmentService
 *
 * Enriches Account records with primary Contact details.
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
     *
     * FIX 1: Moved Contact SOQL outside the for-loop into a single bulk query,
     *         keyed by AccountId, to avoid hitting the 100-SOQL governor limit.
     * FIX 2: Added isEmpty() guard before accessing contacts[0] to prevent
     *         System.ListException: List index out of bounds: 0.
     * FIX 3: Added null check on primary.Email before calling .toLowerCase()
     *         to prevent System.NullPointerException.
     */
    @AuraEnabled
    public static void enrichAccountsWithContactData(List<Id> accountIds) {
        try {
            List<Account> accounts = [
                SELECT Id, Name, Phone, Description
                FROM Account
                WHERE Id IN :accountIds
            ];

            // FIX 1: Single bulk SOQL query for all relevant Contacts, outside the loop
            List<Contact> allContacts = [
                SELECT Id, Email, Phone, AccountId
                FROM Contact
                WHERE AccountId IN :accountIds
            ];

            // Build a map of AccountId -> first Contact found
            Map<Id, Contact> primaryContactByAccountId = new Map<Id, Contact>();
            for (Contact c : allContacts) {
                if (!primaryContactByAccountId.containsKey(c.AccountId)) {
                    primaryContactByAccountId.put(c.AccountId, c);
                }
            }

            List<Account> toUpdate = new List<Account>();

            for (Account acc : accounts) {
                // FIX 2: Guard against accounts with no contacts (was: contacts[0] with no size check)
                if (!primaryContactByAccountId.containsKey(acc.Id)) {
                    continue;
                }

                Contact primary = primaryContactByAccountId.get(acc.Id);

                // FIX 3: Null-safe Email access (was: primary.Email.toLowerCase() with no null check)
                String emailLower = (primary.Email != null) ? primary.Email.toLowerCase() : '';
                acc.Description = 'Primary contact: ' + emailLower;
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
