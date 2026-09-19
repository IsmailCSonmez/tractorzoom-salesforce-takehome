@IsTest
private class AuctionListingControllerTest {

    @TestSetup
    static void makeData() {
        List<Auction_Listing__c> listings = new List<Auction_Listing__c>{
            new Auction_Listing__c(
                Title__c = 'John Deere 8R Tractor',
                Description__c = 'Well-maintained 2020 model',
                Category__c = 'Tractor',
                Starting_Price__c = 85000,
                Status__c = 'Active',
                Ends_At__c = System.now().addDays(7)
            ),
            new Auction_Listing__c(
                Title__c = 'Case IH Combine',
                Description__c = 'Ready for harvest season',
                Category__c = 'Combine',
                Starting_Price__c = 220000,
                Status__c = 'Active',
                Ends_At__c = System.now().addDays(3)
            ),
            new Auction_Listing__c(
                Title__c = 'Closed Auction',
                Description__c = 'Already ended',
                Category__c = 'Implement',
                Starting_Price__c = 5000,
                Status__c = 'Closed',
                Ends_At__c = System.now().addDays(-1)
            )
        };

        insert listings;
    }

    @IsTest
    static void testGetListingsReturnsAllListingsWhenNoFilters() {
        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(null, null);

        Test.stopTest();

        System.assertEquals(
            3,
            result.listings.size(),
            'Should return all listings when no filters are provided'
        );
    }

    @IsTest
    static void testGetListingsFiltersByCategory() {
        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(null, 'Tractor');

        Test.stopTest();

        System.assertEquals(
            1,
            result.listings.size(),
            'Should return only Tractor listings'
        );

        System.assertEquals(
            'John Deere 8R Tractor',
            result.listings[0].title
        );
    }

    @IsTest
    static void testGetListingsFiltersByTitleSearch() {
        List<Id> searchResultIds = getAllListingIds();

        Test.setFixedSearchResults(searchResultIds);

        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(
                'John Deere',
                null
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.listings.size(),
            'Should return the listing matching the title'
        );

        System.assertEquals(
            'John Deere 8R Tractor',
            result.listings[0].title
        );
    }

    @IsTest
    static void testGetListingsFiltersByDescriptionSearch() {
        List<Id> searchResultIds = getAllListingIds();

        Test.setFixedSearchResults(searchResultIds);

        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(
                'harvest',
                null
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.listings.size(),
            'Should return the listing matching the description'
        );

        System.assertEquals(
            'Case IH Combine',
            result.listings[0].title
        );
    }

    @IsTest
    static void testGetListingsCombinesSearchAndCategoryFilters() {
        Auction_Listing__c combineListing = [
            SELECT Id
            FROM Auction_Listing__c
            WHERE Category__c = 'Combine'
            LIMIT 1
        ];

        Test.setFixedSearchResults(
            new List<Id>{ combineListing.Id }
        );

        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(
                'harvest',
                'Combine'
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.listings.size(),
            'Should apply search and category filters together'
        );

        System.assertEquals(
            'Case IH Combine',
            result.listings[0].title
        );

        System.assertEquals(
            'Combine',
            result.listings[0].category
        );
    }

    @IsTest
    static void testGetListingsReturnsNoResultsForNonMatchingFilters() {
        Auction_Listing__c combineListing = [
            SELECT Id
            FROM Auction_Listing__c
            WHERE Category__c = 'Combine'
            LIMIT 1
        ];

        Test.setFixedSearchResults(
            new List<Id>{ combineListing.Id }
        );

        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(
                'John Deere',
                'Combine'
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.listings.size(),
            'Should return no listings when search and category do not match'
        );
    }

    @IsTest
    static void testGetListingsReturnsNoResultsForSearchWithoutMatch() {
        List<Id> searchResultIds = getAllListingIds();

        Test.setFixedSearchResults(searchResultIds);

        Test.startTest();

        AuctionListingController.ListingsResult result =
            AuctionListingController.getListings(
                'Excavator',
                null
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.listings.size(),
            'Should return no listings when title and description do not match'
        );
    }

    @IsTest
    static void testGetListingReturnsCorrectRecord() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            WHERE Title__c = 'John Deere 8R Tractor'
            LIMIT 1
        ];

        Test.startTest();

        AuctionListingController.ListingWrapper result =
            AuctionListingController.getListing(listing.Id);

        Test.stopTest();

        System.assertEquals(
            'John Deere 8R Tractor',
            result.title
        );

        System.assertEquals(
            'Tractor',
            result.category
        );

        System.assertEquals(
            85000,
            result.startingPrice
        );

        System.assertEquals(
            'Active',
            result.status
        );
    }

    @IsTest
    static void testGetListingThrowsForNonExistentId() {
        Auction_Listing__c temp = new Auction_Listing__c(
            Title__c = 'Temp',
            Category__c = 'Tractor',
            Starting_Price__c = 1000,
            Status__c = 'Active',
            Ends_At__c = System.now().addDays(1)
        );

        insert temp;

        String deletedId = temp.Id;
        delete temp;

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            AuctionListingController.getListing(deletedId);

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected AuraHandledException for non-existent listing ID'
        );
    }

    @IsTest
    static void testCreateListingInsertsRecord() {
        Test.startTest();

        String newId =
            AuctionListingController.createListing(
                'New Grain Cart',
                'Excellent condition',
                'Implement',
                12000,
                '2026-12-01T00:00:00Z',
                null
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            newId,
            'Should return a new record ID'
        );

        Auction_Listing__c created = [
            SELECT Title__c,
                   Status__c
            FROM Auction_Listing__c
            WHERE Id = :newId
        ];

        System.assertEquals(
            'New Grain Cart',
            created.Title__c
        );

        System.assertEquals(
            'Active',
            created.Status__c
        );
    }

    @IsTest
    static void testCreateListingValidatesRequiredFields() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            AuctionListingController.createListing(
                null,
                null,
                null,
                null,
                null,
                null
            );

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected AuraHandledException for missing required fields'
        );
    }

    private static List<Id> getAllListingIds() {
        List<Id> ids = new List<Id>();

        for (Auction_Listing__c listing : [
            SELECT Id
            FROM Auction_Listing__c
        ]) {
            ids.add(listing.Id);
        }

        return ids;
    }
}