public with sharing class BidController {

    public class BidWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String bidderName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String listingId { get; set; }
    }

    @AuraEnabled
    public static BidWrapper placeBid(
        String listingId,
        String bidderName,
        Decimal amount
    ) {
        if (String.isBlank(listingId) || String.isBlank(bidderName) || amount == null) {
            throw new AuraHandledException('All fields are required.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Auction_Listing__c listing = [
                SELECT Id, Status__c, Current_Bid__c, Starting_Price__c, Title__c
                FROM Auction_Listing__c
                WHERE Id = :listingId
                LIMIT 1
                FOR UPDATE
            ];

            if (listing.Status__c != 'Active') {
                throw new AuraHandledException('This auction is not active.');
            }

            Decimal threshold = listing.Current_Bid__c != null
                ? listing.Current_Bid__c
                : listing.Starting_Price__c;

            if (amount <= threshold) {
                throw new AuraHandledException(
                    'Bid must be greater than the current bid of ' + threshold
                );
            }

            listing.Current_Bid__c = amount;
            listing.Current_Bidder__c = bidderName;
            update listing;

            Bid_Placed__e evt = new Bid_Placed__e(
                Listing_Id__c = listing.Id,
                Bidder_Name__c = bidderName,
                New_Bid_Amount__c = amount,
                Title__c = listing.Title__c
            );
            EventBus.publish(evt);

            BidWrapper result = new BidWrapper();
            result.id = listing.Id;
            result.bidderName = bidderName;
            result.amount = amount;
            result.listingId = listing.Id;
            return result;

        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to place bid: ' + e.getMessage());
        }
    }
}