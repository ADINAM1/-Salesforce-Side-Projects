import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getSummary from '@salesforce/apex/EnrollmentController.getSummary';
import enroll from '@salesforce/apex/EnrollmentController.enroll';
import changeStatus from '@salesforce/apex/EnrollmentController.changeStatus';

const CHANNEL = '/event/Enrollment_Change__e';

export default class ProgramEnrollment extends LightningElement {
    @api recordId;
    summary;
    wiredResult;
    selectedContactId;
    subscription;

    @wire(getSummary, { programId: '$recordId' })
    wired(result) {
        this.wiredResult = result;
        if (result.data) {
            this.summary = result.data;
        } else if (result.error) {
            this.toast('Error', this.message(result.error), 'error');
        }
    }

    get percentFull() {
        if (!this.summary || !this.summary.capacity) {
            return 0;
        }
        return Math.min(100, Math.round((this.summary.seatsHeld / this.summary.capacity) * 100));
    }

    get seatsLabel() {
        return this.summary ? `${this.summary.seatsHeld} of ${this.summary.capacity} seats held` : '';
    }

    get noContact() {
        return !this.selectedContactId;
    }

    get hasOffers() {
        return this.summary && this.summary.offered.length > 0;
    }

    get hasEnrolled() {
        return this.summary && this.summary.enrolled.length > 0;
    }

    get hasWaitlist() {
        return this.summary && this.summary.waitlist.length > 0;
    }

    connectedCallback() {
        subscribe(CHANNEL, -1, (msg) => {
            if (msg.data.payload.Program_Id__c === this.recordId) {
                refreshApex(this.wiredResult);
            }
        }).then((sub) => {
            this.subscription = sub;
        });
        onError((err) => {
            // eslint-disable-next-line no-console
            console.error('empApi error', JSON.stringify(err));
        });
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.recordId;
    }

    async handleEnroll() {
        try {
            await enroll({ programId: this.recordId, contactId: this.selectedContactId });
            this.toast('Saved', 'Enrollment created', 'success');
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast('Could not enroll', this.message(e), 'error');
        }
    }

    async handleAction(event) {
        const { id, status } = event.target.dataset;
        try {
            await changeStatus({ enrollmentId: id, newStatus: status });
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast('Update failed', this.message(e), 'error');
        }
    }

    message(e) {
        return e?.body?.message ?? 'Unexpected error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
