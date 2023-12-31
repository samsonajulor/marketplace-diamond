// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC721Facet.sol";
import {SignUtils} from "../libraries/SignUtils.sol";
import {Listing} from "../structs/marketplace.structs.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract MarketPlaceFacet {
    address immutable admin;

    /* ERRORS */
    error NotOwner();
    error NotApproved();
    // error AddressZero();
    // error NoCode();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error ListingNotExistent();
    error ListingNotActive();
    error PriceNotMet(int256 difference);
    error ListingExpired();
    error PriceMismatch(uint256 originalPrice);

    /* EVENTS */
    event ListingCreated(uint256 indexed listingId, Listing);
    event ListingExecuted(uint256 indexed listingId, Listing);
    event ListingEdited(uint256 indexed listingId, Listing);

    constructor() {
        admin = msg.sender;
    }

    function createListing(Listing calldata l) public returns (uint256 lId) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (ERC721Facet(l.token).ownerOf(l.tokenId) != msg.sender)
            revert NotOwner();
        if (!ERC721Facet(l.token).checkIsApprovedForAll(msg.sender, address(this)))
            revert NotApproved();

        if (l.price < 0.01 ether) revert MinPriceTooLow();
        if (l.deadline < block.timestamp) revert DeadlineTooSoon();
        if (l.deadline - block.timestamp < 60 minutes)
            revert MinDurationNotMet();

        // Assert signature
        if (
            !SignUtils.isValid(
                SignUtils.constructMessageHash(
                    l.token,
                    l.tokenId,
                    l.price,
                    l.deadline,
                    l.lister
                ),
                l.sig,
                msg.sender
            )
        ) revert InvalidSignature();

        // append to Storage
        Listing storage li = ds.listings[ds.listingId];
        li.token = l.token;
        li.tokenId = l.tokenId;
        li.price = l.price;
        li.sig = l.sig;
        li.deadline = uint88(l.deadline);
        li.lister = msg.sender;
        li.active = true;

        // Emit event
        emit ListingCreated(ds.listingId, l);
        lId = ds.listingId;
        ds.listingId++;
        return lId;
    }

    function executeListing(uint256 _listingId) public payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_listingId >= ds.listingId) revert ListingNotExistent();
        Listing storage listing = ds.listings[_listingId];
        if (listing.deadline < block.timestamp) revert ListingExpired();
        if (!listing.active) revert ListingNotActive();
        if (listing.price != msg.value)
            revert PriceNotMet(int256(listing.price) - int256(msg.value));

        // Update state
        listing.active = false;

        // transfer
        ERC721Facet(listing.token).transferFrom(
            listing.lister,
            msg.sender,
            listing.tokenId
        );

        // transfer eth
        payable(listing.lister).transfer(listing.price);

        // Update storage
        emit ListingExecuted(_listingId, listing);
    }

    function editListing(
        uint256 _listingId,
        uint256 _newPrice,
        bool _active
    ) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_listingId >= ds.listingId) revert ListingNotExistent();
        Listing storage listing = ds.listings[_listingId];
        if (listing.lister != msg.sender) revert NotOwner();
        listing.price = _newPrice;
        listing.active = _active;
        emit ListingEdited(_listingId, listing);
    }

    // add getter for listing
    function getListing(
        uint256 _listingId
    ) public view returns (Listing memory) {
        // if (_listingId >= listingId)
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.listings[_listingId];
    }
}
