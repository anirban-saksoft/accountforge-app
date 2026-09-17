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
     * FIX 1: SOQL moved outside the for-loop; contacts are fetched in a single
     *         bulk query and stored in a Map<Id, Contact> keyed by AccountId.
     * FIX 2: Added isEmpty() guard before accessing contacts[0] so that Accounts
     *         with no Contacts are safely skipped instead of throwing ListException.
     * FIX 3: Added null-safe check on primary.Email before calling .toLowerCase()
     *         to prevent NullPointerException when Email is blank.
     */
    @AuraEnabled
    public static void enrichAccountsWithContactData(List<Id> accountIds) {
        try {
            List<Account> accounts = [
                SELECT Id, Name, Phone, Description
                FROM Account
                WHERE Id IN :accountIds
            ];

            // FIX 1: Single bulk SOQL query outside the loop
            List<Contact> allContacts = [
                SELECT Id, AccountId, Email, Phone
                FROM Contact
                WHERE AccountId IN :accountIds
            ];

            // Build a map of AccountId -> first Contact found
            Map<Id, Contact> contactByAccountId = new Map<Id, Contact>();
            for (Contact c : allContacts) {
                if (!contactByAccountId.containsKey(c.AccountId)) {
                    contactByAccountId.put(c.AccountId, c);
                }
            }

            List<Account> toUpdate = new List<Account>();

            for (Account acc : accounts) {
                // FIX 2: Guard against Accounts that have no Contacts
                if (!contactByAccountId.containsKey(acc.Id)) {
                    continue;
                }

                Contact primary = contactByAccountId.get(acc.Id);

                // FIX 3: Null-safe Email access before calling .toLowerCase()
                String emailLower = (primary.Email != null)
                    ? primary.Email.toLowerCase()
                    : '';

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
