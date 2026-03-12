import { LightningElement, api } from 'lwc';
import getCaseUiView from '@salesforce/apex/CaseEmailWorkspaceController.getCaseUiView';

export default class CaseEmailSummaryPanel extends LightningElement {
    @api recordId;

    viewModel;
    isLoading = false;
    errorMessage;

    connectedCallback() {
        this.loadView();
    }

    get summaryText() {
        return this.viewModel?.agentOutput?.summary || 'No summary available.';
    }

    get categoryText() {
        return this.viewModel?.agentOutput?.category || 'Not available';
    }

    get intentText() {
        return this.viewModel?.agentOutput?.intent || 'NONE';
    }

    get newEmailAddressText() {
        return this.viewModel?.agentOutput?.newEmailAddress || 'Not detected';
    }

    async loadView() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            this.viewModel = await getCaseUiView({ caseId: this.recordId });
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Unable to load case resend data.';
        } finally {
            this.isLoading = false;
        }
    }

    handleRefreshRequested() {
        this.loadView();
    }
}
