import { LightningElement, api } from 'lwc';
import sendAll from '@salesforce/apex/CaseEmailWorkspaceController.sendAll';

export default class CaseResendTable extends LightningElement {
    @api recordId;
    @api rows = [];
    @api canSendAll = false;

    isSubmitting = false;
    statusMessage;

    get hasRows() {
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    get disableSendAll() {
        return this.isSubmitting || !this.canSendAll;
    }

    async handleSendAll() {
        this.isSubmitting = true;
        this.statusMessage = undefined;
        try {
            const result = await sendAll({ caseId: this.recordId });
            this.statusMessage = result?.message || 'Send All request submitted.';
            this.dispatchEvent(new CustomEvent('refreshrequested'));
        } catch (error) {
            this.statusMessage = error?.body?.message || error?.message || 'Send All failed.';
        } finally {
            this.isSubmitting = false;
        }
    }
}
