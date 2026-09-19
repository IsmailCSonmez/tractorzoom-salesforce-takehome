import { LightningElement, api, track } from 'lwc';
import getListing from '@salesforce/apex/AuctionListingController.getListing';
import getBidHistory from '@salesforce/apex/BidController.getBidHistory';
import { subscribe, unsubscribe } from 'lightning/empApi';

const FALLBACK_IMAGE = 'https://placehold.co/800x400/e8e8e8/666?text=No+Image';

export default class AuctionListingDetail extends LightningElement {
    @api listingId;

    @track listing = null;
    @track bidHistory = [];
    @track isLoading = false;

    _subscription = null;

    connectedCallback() {
        this.refreshData();

        subscribe('/event/Bid_Placed__e', -1, (event) => {
            if (event.data.payload.Listing_Id__c === this.listingId) {
                this.refreshData();
            }
        }).then((sub) => {
            this._subscription = sub;
        });
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription, () => {});
        }
    }

    refreshData() {
        this.loadListing();
        this.loadBidHistory();
    }

    loadListing() {
        this.isLoading = true;

        getListing({ listingId: this.listingId })
            .then((result) => {
                this.listing = result;
                this.isLoading = false;
            })
            .catch((error) => {
                console.error('Error loading listing:', error);
                this.isLoading = false;
            });
    }

    loadBidHistory() {
        getBidHistory({ listingId: this.listingId })
            .then((result) => {
                this.bidHistory = result.map((bid, index) => ({
                    ...bid,
                    isHighest: index === 0,
                    rowClass: index === 0 ? 'bid-row highest-bid' : 'bid-row',
                    amountDisplay: new Intl.NumberFormat('en-US', {
                        style: 'currency',
                        currency: 'USD'
                    }).format(bid.amount),
                    bidTimeDisplay: bid.bidTime ? new Date(bid.bidTime).toLocaleString() : ''
                }));
            })
            .catch((error) => {
                console.error('Error loading bid history:', error);
                this.bidHistory = [];
            });
    }

    handleBidSuccess() {
        this.refreshData();
        this.dispatchEvent(new CustomEvent('bidsuccess'));
    }

    handleImageError(event) {
        event.target.src = FALLBACK_IMAGE;
    }

    get imageUrl() {
        return this.listing && this.listing.imageUrl ? this.listing.imageUrl : FALLBACK_IMAGE;
    }

    get isActive() {
        return this.listing && this.listing.status === 'Active';
    }

    get hasBidHistory() {
        return this.bidHistory.length > 0;
    }

    get startingPriceDisplay() {
        return this.listing
            ? new Intl.NumberFormat('en-US', {
                  style: 'currency',
                  currency: 'USD'
              }).format(this.listing.startingPrice)
            : '';
    }

    get currentBidDisplay() {
        if (!this.listing) {
            return '';
        }

        const amount = this.listing.currentBid || this.listing.startingPrice;

        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(amount);
    }

    get formattedEndsAt() {
        if (!this.listing || !this.listing.endsAt) {
            return '';
        }

        return new Date(this.listing.endsAt).toLocaleString();
    }

    get categoryBadgeClass() {
        if (!this.listing) {
            return 'slds-badge';
        }

        const colors = {
            Tractor: 'slds-badge slds-badge_lightest category-tractor',
            Combine: 'slds-badge slds-badge_lightest category-combine',
            Implement: 'slds-badge slds-badge_lightest category-implement',
            Attachment: 'slds-badge slds-badge_lightest category-attachment'
        };

        return colors[this.listing.category] || 'slds-badge';
    }

    get statusBadgeClass() {
        if (!this.listing) {
            return 'slds-badge';
        }

        return this.listing.status === 'Active' ? 'slds-badge slds-badge_success' : 'slds-badge';
    }
}
