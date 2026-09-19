public with sharing class AuctionListingController {

    public class ListingWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Decimal startingPrice { get; set; }
        @AuraEnabled public Decimal currentBid { get; set; }
        @AuraEnabled public String currentBidder { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String endsAt { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
    }

    public class ListingsResult {
        @AuraEnabled public List<ListingWrapper> listings { get; set; }
    }

    @AuraEnabled
    public static ListingsResult getListings(
        String searchTerm,
        String category
    ) {
        List<Auction_Listing__c> listings = queryListings(
            searchTerm,
            category
        );

        ListingsResult result = new ListingsResult();
        result.listings = new List<ListingWrapper>();

        for (Auction_Listing__c listing : listings) {
            result.listings.add(toWrapper(listing));
        }

        return result;
    }

    @AuraEnabled
    public static ListingWrapper getListing(String listingId) {
        try {
            Auction_Listing__c listing = [
                SELECT Id,
                       Title__c,
                       Description__c,
                       Category__c,
                       Starting_Price__c,
                       Current_Bid__c,
                       Current_Bidder__c,
                       Status__c,
                       Ends_At__c,
                       Image_URL__c
                FROM Auction_Listing__c
                WHERE Id = :listingId
                LIMIT 1
            ];

            return toWrapper(listing);

        } catch (Exception e) {
            throw new AuraHandledException(
                'Listing not found: ' + e.getMessage()
            );
        }
    }

    @AuraEnabled
    public static String createListing(
        String title,
        String description,
        String category,
        Decimal startingPrice,
        String endsAt,
        String imageUrl
    ) {
        if (
            String.isBlank(title) ||
            String.isBlank(category) ||
            startingPrice == null ||
            String.isBlank(endsAt)
        ) {
            throw new AuraHandledException(
                'Title, category, starting price, and end date are required.'
            );
        }

        if (!Auction_Listing__c.sObjectType.getDescribe().isCreateable()) {
            throw new AuraHandledException(
                'Insufficient permissions to create listings.'
            );
        }

        try {
            String normalizedEndsAt = endsAt
                .replace('T', ' ')
                .removeEnd('Z')
                .left(19);

            if (normalizedEndsAt.length() == 16) {
                normalizedEndsAt += ':00';
            }

            Auction_Listing__c listing = new Auction_Listing__c(
                Title__c = title,
                Description__c = description,
                Category__c = category,
                Starting_Price__c = startingPrice,
                Current_Bid__c = null,
                Current_Bidder__c = null,
                Status__c = 'Active',
                Ends_At__c = DateTime.valueOfGmt(normalizedEndsAt),
                Image_URL__c = imageUrl
            );

            insert listing;

            return listing.Id;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static List<Auction_Listing__c> queryListings(
        String searchTerm,
        String category
    ) {
        String normalizedSearch = String.isBlank(searchTerm)
            ? null
            : searchTerm.trim();

        /*
         * Do not run a text search for a single character.
         * Treat it like no search term until at least two
         * characters have been entered.
         */
        if (
            normalizedSearch != null &&
            normalizedSearch.length() < 2
        ) {
            normalizedSearch = null;
        }

        String categoryFilter = String.isBlank(category)
            ? null
            : category;

        /*
         * No text search:
         * use SOQL and optionally filter by category.
         */
        if (normalizedSearch == null) {

            if (categoryFilter == null) {
                return [
                    SELECT Id,
                           Title__c,
                           Description__c,
                           Category__c,
                           Starting_Price__c,
                           Current_Bid__c,
                           Current_Bidder__c,
                           Status__c,
                           Ends_At__c,
                           Image_URL__c
                    FROM Auction_Listing__c
                    ORDER BY Ends_At__c ASC
                ];
            }

            return [
                SELECT Id,
                       Title__c,
                       Description__c,
                       Category__c,
                       Starting_Price__c,
                       Current_Bid__c,
                       Current_Bidder__c,
                       Status__c,
                       Ends_At__c,
                       Image_URL__c
                FROM Auction_Listing__c
                WHERE Category__c = :categoryFilter
                ORDER BY Ends_At__c ASC
            ];
        }

        /*
         * Text search:
         * Description__c is a Long Text Area, so it cannot be
         * filtered in a SOQL WHERE clause.
         *
         * SOSL finds candidate records.
         * The wildcard allows prefix searches such as:
         * "cor" -> "corn".
         */
        String soslSearch = normalizedSearch + '*';

        List<List<SObject>> searchResults;

        if (categoryFilter == null) {
            searchResults = [
                FIND :soslSearch
                IN ALL FIELDS
                RETURNING Auction_Listing__c(
                    Id,
                    Title__c,
                    Description__c,
                    Category__c,
                    Starting_Price__c,
                    Current_Bid__c,
                    Current_Bidder__c,
                    Status__c,
                    Ends_At__c,
                    Image_URL__c
                    ORDER BY Ends_At__c ASC
                )
            ];
        } else {
            searchResults = [
                FIND :soslSearch
                IN ALL FIELDS
                RETURNING Auction_Listing__c(
                    Id,
                    Title__c,
                    Description__c,
                    Category__c,
                    Starting_Price__c,
                    Current_Bid__c,
                    Current_Bidder__c,
                    Status__c,
                    Ends_At__c,
                    Image_URL__c
                    WHERE Category__c = :categoryFilter
                    ORDER BY Ends_At__c ASC
                )
            ];
        }

        List<Auction_Listing__c> candidates =
            (List<Auction_Listing__c>) searchResults[0];

        /*
         * SOSL searches across searchable fields.
         * The UI requirement is specifically title OR description,
         * so validate the candidates against those fields.
         */
        String searchValue = normalizedSearch.toLowerCase();

        List<Auction_Listing__c> filteredListings =
            new List<Auction_Listing__c>();

        for (Auction_Listing__c listing : candidates) {

            Boolean titleMatches =
                listing.Title__c != null &&
                listing.Title__c
                    .toLowerCase()
                    .contains(searchValue);

            Boolean descriptionMatches =
                listing.Description__c != null &&
                listing.Description__c
                    .toLowerCase()
                    .contains(searchValue);

            if (titleMatches || descriptionMatches) {
                filteredListings.add(listing);
            }
        }

        return filteredListings;
    }

    private static ListingWrapper toWrapper(
        Auction_Listing__c listing
    ) {
        ListingWrapper wrapper = new ListingWrapper();

        wrapper.id = listing.Id;
        wrapper.title = listing.Title__c;
        wrapper.description = listing.Description__c;
        wrapper.category = listing.Category__c;
        wrapper.startingPrice = listing.Starting_Price__c;
        wrapper.currentBid = listing.Current_Bid__c;
        wrapper.currentBidder = listing.Current_Bidder__c;
        wrapper.status = listing.Status__c;

        wrapper.endsAt = listing.Ends_At__c != null
            ? listing.Ends_At__c.formatGmt(
                'yyyy-MM-dd\'T\'HH:mm:ss\'Z\''
            )
            : null;

        wrapper.imageUrl = listing.Image_URL__c;

        return wrapper;
    }
}