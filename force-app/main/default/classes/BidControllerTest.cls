@IsTest
private class BidControllerTest {

    @TestSetup
    static void makeData() {
        Auction_Listing__c listing = new Auction_Listing__c(
            Title__c = 'Test Tractor',
            Category__c = 'Tractor',
            Starting_Price__c = 10000,
            Status__c = 'Active',
            Ends_At__c = System.now().addDays(7)
        );

        insert listing;
    }

    @IsTest
    static void testPlaceBidSucceedsAndPersistsHistory() {
        Auction_Listing__c listing = [
            SELECT Id, Starting_Price__c
            FROM Auction_Listing__c
            LIMIT 1
        ];

        Test.startTest();

        BidController.BidWrapper result =
            BidController.placeBid(
                listing.Id,
                'Jane Smith',
                15000
            );

        Test.stopTest();

        System.assertEquals(
            'Jane Smith',
            result.bidderName
        );

        System.assertEquals(
            15000,
            result.amount
        );

        System.assertEquals(
            listing.Id,
            result.listingId
        );

        System.assertNotEquals(
            null,
            result.id
        );

        Auction_Listing__c updated = [
            SELECT Current_Bid__c,
                   Current_Bidder__c
            FROM Auction_Listing__c
            WHERE Id = :listing.Id
        ];

        System.assertEquals(
            15000,
            updated.Current_Bid__c
        );

        System.assertEquals(
            'Jane Smith',
            updated.Current_Bidder__c
        );

        List<Bid__c> bids = [
            SELECT Auction_Listing__c,
                   Bidder_Name__c,
                   Amount__c,
                   Bid_Time__c
            FROM Bid__c
            WHERE Auction_Listing__c = :listing.Id
        ];

        System.assertEquals(
            1,
            bids.size(),
            'Successful bid should create one Bid__c history record'
        );

        System.assertEquals(
            'Jane Smith',
            bids[0].Bidder_Name__c
        );

        System.assertEquals(
            15000,
            bids[0].Amount__c
        );

        System.assertNotEquals(
            null,
            bids[0].Bid_Time__c
        );
    }

    @IsTest
    static void testPlaceBidRejectsLowBid() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            BidController.placeBid(
                listing.Id,
                'Jane Smith',
                5000
            );

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected AuraHandledException for low bid'
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Bid__c
                WHERE Auction_Listing__c = :listing.Id
            ],
            'Rejected bid should not create history'
        );
    }

    @IsTest
    static void testPlaceBidRejectsEqualBid() {
        Auction_Listing__c listing = [
            SELECT Id, Starting_Price__c
            FROM Auction_Listing__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            BidController.placeBid(
                listing.Id,
                'Jane Smith',
                listing.Starting_Price__c
            );

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'A bid equal to the current threshold should be rejected'
        );
    }

    @IsTest
    static void testPlaceBidRejectsClosedAuction() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            LIMIT 1
        ];

        listing.Status__c = 'Closed';
        update listing;

        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            BidController.placeBid(
                listing.Id,
                'Jane Smith',
                15000
            );

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected AuraHandledException for closed auction'
        );
    }

    @IsTest
    static void testPlaceBidValidatesRequiredFields() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            BidController.placeBid(
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
            'Expected AuraHandledException for missing fields'
        );
    }

    @IsTest
    static void testMultipleBidsPreserveHistoryAndHighestBid() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            LIMIT 1
        ];

        Test.startTest();

        BidController.placeBid(
            listing.Id,
            'Jane Smith',
            12000
        );

        BidController.placeBid(
            listing.Id,
            'John Doe',
            14000
        );

        BidController.placeBid(
            listing.Id,
            'Ismail',
            16000
        );

        Test.stopTest();

        Auction_Listing__c updated = [
            SELECT Current_Bid__c,
                   Current_Bidder__c
            FROM Auction_Listing__c
            WHERE Id = :listing.Id
        ];

        System.assertEquals(
            16000,
            updated.Current_Bid__c
        );

        System.assertEquals(
            'Ismail',
            updated.Current_Bidder__c
        );

        List<Bid__c> bids = [
            SELECT Bidder_Name__c,
                   Amount__c
            FROM Bid__c
            WHERE Auction_Listing__c = :listing.Id
        ];

        System.assertEquals(
            3,
            bids.size(),
            'All successful bids should be preserved'
        );
    }

    @IsTest
    static void testGetBidHistoryReturnsHighestBidFirst() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            LIMIT 1
        ];

        BidController.placeBid(
            listing.Id,
            'Jane Smith',
            12000
        );

        BidController.placeBid(
            listing.Id,
            'John Doe',
            14000
        );

        BidController.placeBid(
            listing.Id,
            'Ismail',
            16000
        );

        Test.startTest();

        List<BidController.BidHistoryWrapper> history =
            BidController.getBidHistory(listing.Id);

        Test.stopTest();

        System.assertEquals(
            3,
            history.size()
        );

        System.assertEquals(
            16000,
            history[0].amount,
            'Highest bid should be first'
        );

        System.assertEquals(
            'Ismail',
            history[0].bidderName
        );

        System.assertEquals(
            14000,
            history[1].amount
        );

        System.assertEquals(
            12000,
            history[2].amount
        );

        System.assertNotEquals(
            null,
            history[0].bidTime
        );
    }

    @IsTest
    static void testGetBidHistoryReturnsEmptyListWhenNoBidsExist() {
        Auction_Listing__c listing = [
            SELECT Id
            FROM Auction_Listing__c
            LIMIT 1
        ];

        Test.startTest();

        List<BidController.BidHistoryWrapper> history =
            BidController.getBidHistory(listing.Id);

        Test.stopTest();

        System.assertEquals(
            0,
            history.size(),
            'Listing without bids should return an empty history'
        );
    }

    @IsTest
    static void testGetBidHistoryValidatesListingId() {
        Boolean exceptionThrown = false;

        try {
            Test.startTest();

            BidController.getBidHistory(null);

            Test.stopTest();

        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(
            exceptionThrown,
            'Expected AuraHandledException when listing ID is missing'
        );
    }
}