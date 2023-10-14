# NFT MarketPlace Diamonds

This repository implements the Diamond EIP (ERC-2535) by Nick Mudge to create Facets for a simple NFT MarketPlace imitation.

It includes the following functions:

createListing(Listing calldata l)

Description: Allows a user to create a new listing in the marketplace.
Parameters:
l: A Listing struct containing details of the listing.
Returns: The unique identifier (listingId) of the created listing.
executeListing(uint256 _listingId)

Description: Enables a user to purchase and execute a listing.
Parameters:
_listingId: The unique identifier of the listing to be executed.
Requires payment in Ether equal to the listing price.
editListing(uint256 _listingId, uint256 _newPrice, bool _active)

Description: Allows the listing owner to edit an existing listing, changing its price and availability status.
Parameters:
_listingId: The unique identifier of the listing to be edited.
_newPrice: The new price for the listing.
_active: A boolean indicating the listing's availability status.
getListing(uint256 _listingId)

Description: Retrieves information about a specific listing.
Parameters:
_listingId: The unique identifier of the listing to be retrieved.
Returns: A Listing struct containing details of the listing.

## Installation

- Clone this repo
- Install dependencies

```bash
$ forge update
```

### Foundry

```bash
$ forge t
```

Bonus: The [DiamondLoupefacet](contracts/facets/DiamondLoupeFacet.sol) uses an updated [LibDiamond](contracts/libraries//LibDiamond.sol) which utilises solidity custom errors to make debugging easier especially when upgrading diamonds.
