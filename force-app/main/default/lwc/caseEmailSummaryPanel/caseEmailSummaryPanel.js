import { LightningElement, api } from 'lwc';
import getCaseUiView from '@salesforce/apex/FT_CaseEmailWorkspaceController.getCaseUiView';

export default class CaseEmailSummaryPanel extends LightningElement {
    @api recordId;

    viewModel;
    isLoading = false;
    errorMessage;

    connectedCallback() {
        this.loadView();
    }

    get summaryText() {
        return this.viewModel?.summaryResult?.summary || 'No summary available.';
    }

    get historySummaryText() {
        return this.viewModel?.summaryResult?.historySummary || 'No email history summary available.';
    }

    get intentText() {
        return this.viewModel?.summaryResult?.detectedIntent || 'NONE';
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
