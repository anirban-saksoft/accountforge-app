/**
 * CaseEscalationService
 *
 * Escalates overdue Cases by updating their Priority and Status,
 * and calculates an urgency score from the Description field.
 * DEMO NOTE: Contains 3 intentional bugs for the Issue Triage Agent showcase.
 *
 * BUG 1 — DML inside for loop (line 55)
 *   Impact : Governor LimitException — DML statements exceed 150 in large sets
 *   Trigger: Call escalateOverdueCases() with more than 150 Case IDs
 *
 * BUG 2 — Integer.valueOf() on non-numeric string (line 59)
 *   Impact : System.TypeException: Invalid integer
 *   Trigger: Call with any Case whose Description is plain text (not a number)
 *
 * BUG 3 — Divide by zero (line 62)
 *   Impact : System.MathException: Divide by 0
 *   Trigger: Call with a Case whose Description is '0'
 */
public class CaseEscalationService {

    /**
     * Called by caseEscalationPanel LWC to populate the list on load.
     */
    @AuraEnabled(cacheable=true)
    public static List<Case> getOpenCases() {
        return [
            SELECT Id, Subject, Status, Priority, Description, CreatedDate
            FROM Case
            WHERE Status != 'Closed'
            ORDER BY CreatedDate ASC
            LIMIT 50
        ];
    }

    /**
     * Called by caseEscalationPanel LWC when user clicks Escalate.
     * NOTE: The LWC passes a String instead of List<Id> — this causes
     * an additional System.TypeException on the client call itself.
     */
    @AuraEnabled
    public static void escalateOverdueCasesLWC(List<Id> caseIds) {
        escalateOverdueCases(caseIds);
    }

    /**
     * Core escalation logic — INTENTIONALLY BROKEN for demo purposes.
     */
    public static void escalateOverdueCases(List<Id> caseIds) {
        List<Case> cases = [
            SELECT Id, Status, Priority, Description
            FROM Case
            WHERE Id IN :caseIds
        ];

        for (Case c : cases) {
            c.Priority = 'High';
            c.Status   = 'In Progress';

            // BUG 1: DML inside for loop — each iteration consumes one DML statement
            update c;

            // BUG 2: Integer.valueOf throws System.TypeException on any non-integer string
            Integer slaHours = Integer.valueOf(c.Description);

            // BUG 3: Division by zero when Description is '0'
            Decimal urgencyScore = 100 / slaHours;
            System.debug('Urgency score for case ' + c.Id + ': ' + urgencyScore);
        }
    }
}