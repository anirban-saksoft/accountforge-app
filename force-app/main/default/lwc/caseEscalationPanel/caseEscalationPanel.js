/**
 * caseEscalationPanel
 *
 * Lists open Cases and lets a user escalate them with one click.
 * DEMO NOTE: Contains 4 intentional bugs for the Issue Triage Agent showcase.
 *
 * BUG 1 — Unhandled promise rejection on initial load (connectedCallback, line 34)
 *   Impact : Uncaught (in promise) — component silently shows nothing if the
 *            Apex call fails. isLoading stays true (spinner never stops).
 *   Trigger: Open the component when the org has no Cases or Apex throws.
 *
 * BUG 2 — String passed where List<Id> expected (handleEscalate, line 45)
 *   Impact : System.TypeException on the server — Apex receives a String,
 *            not a List<Id>, and cannot deserialize it.
 *   Trigger: Click Escalate on any case row.
 *
 * BUG 3 — Mutation of tracked array items not reactive (handleEscalate, line 51)
 *   Impact : UI does not update after escalation — Status stays 'Open' on screen
 *            even though the variable changed. LWC reactive system does not
 *            detect direct property mutations inside @track arrays.
 *   Trigger: Escalate any case — the button label and status do not reflect change.
 *
 * BUG 4 — Property access on undefined (handleEscalate, line 54)
 *   Impact : TypeError: Cannot read properties of undefined (reading 'toUpperCase')
 *            If Array.find() returns undefined (case not in list), .Subject crashes.
 *   Trigger: Escalate a case whose ID is somehow not in the current cases array.
 */
import { LightningElement, track } from 'lwc';
import getOpenCases from '@salesforce/apex/CaseEscalationService.getOpenCases';
import escalateOverdueCasesLWC from '@salesforce/apex/CaseEscalationService.escalateOverdueCasesLWC';

export default class CaseEscalationPanel extends LightningElement {
    @track cases = [];
    @track isLoading = false;

    connectedCallback() {
        this.isLoading = true;
        // BUG 1: No .catch() — unhandled promise rejection; isLoading never resets on error
        // Correct: add .catch(err => { this.isLoading = false; console.error(err); })
        getOpenCases()
            .then(result => {
                this.cases = result;
                this.isLoading = false;
            });
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    handleEscalate(event) {
        const caseId = event.target.dataset.id;

        // BUG 2: Passing a String — Apex expects List<Id>, receives a scalar String
        // Correct: { caseIds: [caseId] }
        escalateOverdueCasesLWC({ caseIds: caseId })
            .then(() => {
                // BUG 3: Direct mutation of object inside @track array — not reactive
                // Correct: replace the array item entirely to trigger re-render
                const target = this.cases.find(c => c.Id === caseId);
                target.Status = 'In Progress';

                // BUG 4: target is undefined if find() returns nothing — .Subject throws
                // Correct: if (target) { console.log(...) }
                console.log('Escalated: ' + target.Subject.toUpperCase());
            })
            .catch(error => {
                // Note: error.message is undefined in LWC — correct path is error.body.message
                console.error('Escalation failed: ' + error.message);
            });
    }
}