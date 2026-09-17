/**
 * accountDashboard
 *
 * Displays Account details including revenue and primary Contact.
 * DEMO NOTE: Contains 4 intentional bugs for the Issue Triage Agent showcase.
 *
 * BUG 1 — Wire error not handled (wiredAccount, line 28)
 *   Impact : Silent failure — when Apex throws, the component shows nothing and
 *            swallows the error. No feedback to the user.
 *   Trigger: Enter an invalid or non-existent Account ID and click Load Account.
 *
 * BUG 2 — Wrong property path on Contacts sub-query (primaryContactName, line 38)
 *   Impact : TypeError: Cannot read properties of undefined (reading '0')
 *            Wire returns Contacts as { records: [...] }, not a plain array.
 *   Trigger: Any Account loaded that has at least one Contact.
 *
 * BUG 3 — toFixed() on NaN (formattedRevenue, line 45)
 *   Impact : TypeError: Cannot read properties of undefined
 *            parseInt(undefined) returns NaN; NaN.toFixed() throws.
 *   Trigger: Any Account with a null AnnualRevenue field.
 *
 * BUG 4 — Unhandled promise rejection (handleLoadAccount, line 52)
 *   Impact : Uncaught (in promise) — error shown in browser console only,
 *            user sees no feedback.
 *   Trigger: Click Load Account with any ID.
 */
import { LightningElement, wire, track } from 'lwc';
import getAccountDetails from '@salesforce/apex/AccountEnrichmentService.getAccountDetails';

export default class AccountDashboard extends LightningElement {
    @wire(getAccountDetails, { accountId: '$currentAccountId' })
    account;
    // BUG 1: Should destructure { data, error } and handle the error branch:
    // wiredAccount({ data, error }) {
    //     if (data) { this.account = data; }
    //     else if (error) { this.error = error.body?.message; }
    // }

    @track currentAccountId;
    @track manualAccountId = '';
    @track error;

    get primaryContactName() {
        // BUG 2: Contacts is a relationship object — sub-query returns { records: [...] }
        // Correct: this.account.data?.Contacts?.records[0]?.Name ?? '—'
        return this.account.data.Contacts[0].Name;
    }

    get formattedRevenue() {
        // BUG 3: AnnualRevenue may be null — parseInt(null) → NaN → NaN.toFixed() throws
        // Correct: this.account.data?.AnnualRevenue
        //              ? '$' + Number(this.account.data.AnnualRevenue).toFixed(2) : '—'
        const revenue = this.account.data.AnnualRevenue;
        return '$' + parseInt(revenue).toFixed(2);
    }

    handleIdChange(event) {
        this.manualAccountId = event.target.value;
    }

    handleLoadAccount() {
        // BUG 4: No .catch() — unhandled promise rejection, user sees no error message
        // Correct: add .catch(err => { this.error = err.body?.message || err.message; })
        getAccountDetails({ accountId: this.manualAccountId })
            .then(() => {
                this.currentAccountId = this.manualAccountId;
            });
    }
}