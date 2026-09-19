import { LightningElement } from 'lwc';
import getListings from '@salesforce/apex/AuctionListingController.getListings';

export default class AuctionApp extends LightningElement {
    listings = [];
    isLoading = false;
    selectedListingId = null;
    showCreateForm = false;

    searchTerm = '';
    selectedCategory = '';

    searchDebounceTimeout;
    requestSequence = 0;

    categoryOptions = [
        { label: 'All Categories', value: '' },
        { label: 'Tractor', value: 'Tractor' },
        { label: 'Combine', value: 'Combine' },
        { label: 'Implement', value: 'Implement' },
        { label: 'Attachment', value: 'Attachment' }
    ];

    connectedCallback() {
        this.loadListings();
    }

    disconnectedCallback() {
        clearTimeout(this.searchDebounceTimeout);
    }

    loadListings() {
        const requestId = ++this.requestSequence;

        this.isLoading = true;

        getListings({
            searchTerm: this.searchTerm,
            category: this.selectedCategory
        })
            .then((result) => {
                if (requestId === this.requestSequence) {
                    this.listings = result.listings;
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                if (requestId === this.requestSequence) {
                    console.error('Error loading listings:', error);
                    this.isLoading = false;
                }
            });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;

        clearTimeout(this.searchDebounceTimeout);

        this.searchDebounceTimeout = setTimeout(() => {
            this.loadListings();
        }, 300);
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;

        clearTimeout(this.searchDebounceTimeout);
        this.loadListings();
    }

    handleListingSelect(event) {
        this.selectedListingId = event.detail.listingId;
        this.showCreateForm = false;
    }

    handleShowCreateForm() {
        this.showCreateForm = true;
        this.selectedListingId = null;
    }

    handleCreateCancel() {
        this.showCreateForm = false;
    }

    handleListingCreated(event) {
        this.showCreateForm = false;
        this.selectedListingId = event.detail.listingId;
        this.loadListings();
    }

    handleBidSuccess() {
        this.loadListings();
    }

    get noListings() {
        return !this.isLoading && this.listings.length === 0;
    }
}
