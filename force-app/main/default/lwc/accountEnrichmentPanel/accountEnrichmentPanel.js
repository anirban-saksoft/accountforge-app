import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountsForEnrichment from '@salesforce/apex/AccountEnrichmentService.getAccountsForEnrichment';
import enrichAccountsWithContactData from '@salesforce/apex/AccountEnrichmentService.enrichAccountsWithContactData';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'Name' },
    { label: 'Phone', fieldName: 'Phone' },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' }
];

export default class AccountEnrichmentPanel extends LightningElement {
    columns = COLUMNS;
    selectedIds = [];
    isLoading = false;
    accounts;

    wiredAccountsResult;

    @wire(getAccountsForEnrichment)
    wiredAccounts(result) {
        this.wiredAccountsResult = result;
        this.accounts = result;
    }

    get isEnrichDisabled() {
        return this.isLoading || this.selectedIds.length === 0;
    }

    handleRowSelection(event) {
        this.selectedIds = event.detail.selectedRows.map((row) => row.Id);
    }

    handleEnrichSelected() {
        this.isLoading = true;

        enrichAccountsWithContactData({ accountIds: this.selectedIds })
            .then(() => refreshApex(this.wiredAccountsResult))
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Account Enrichment Failed',
                        message: this.extractErrorMessage(error),
                        variant: 'error',
                        mode: 'dismissable'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}