// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/MarketPlaceFacet.sol";

import "./helpers/DiamondUtils.sol";
import {
    Helpers
} from "./helpers/MarketPlaceUtils.sol";
import "../contracts/ERC721Mock.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    MarketPlaceFacet marketF;
    Listing l;
    OurNFT nft;
    address dayo;
    address motunrayo;
    address tope;

    uint256 privKeyA;
    uint256 privKeyB;
    // uint256 user
    function mkaddr(
        string memory name
    ) public returns (address addr, uint256 privateKey) {
        privateKey = uint256(keccak256(abi.encodePacked(name)));
        // address addr = address(uint160(uint256(keccak256(abi.encodePacked(name)))))
        addr = vm.addr(privateKey);
        vm.label(addr, name);
    }

    function constructSig(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        uint88 _deadline,
        address _seller,
        uint256 privKey
    ) public pure returns (bytes memory sig) {
        bytes32 mHash = keccak256(
            abi.encodePacked(_token, _tokenId, _price, _deadline, _seller)
        );

        mHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", mHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, mHash);
        sig = getSig(v, r, s);
    }

    function getSig(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory sig) {
        sig = bytes.concat(r, s, bytes1(v));
    }

    function switchSigner(address _newSigner) public {
        vm.startPrank(_newSigner);
        vm.deal(_newSigner, 4 ether);
    }

    function setUp() public {
        // market place setup

        (dayo, privKeyA) = mkaddr("DAYO");
        (motunrayo, privKeyB) = mkaddr("MOTUN");

        // switchSigner(dayo);
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        marketF = new MarketPlaceFacet();
        nft = new OurNFT();



        l = Listing({
            token: address(nft),
            tokenId: 1,
            price: 1 ether,
            sig: bytes(""),
            deadline: 0,
            lister: address(0),
            active: false
        });

        // mint NFT
        nft.mint(dayo, 1);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(marketF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("MarketPlaceFacet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}



    function testOwnerCannotCreateListing() public {
        l.lister = motunrayo;
        switchSigner(motunrayo);

        vm.expectRevert(MarketPlaceFacet.NotOwner.selector);
        marketF.createListing(l);
    }

    function testNonApprovedNFT() public {
        switchSigner(dayo);
        vm.expectRevert(MarketPlaceFacet.NotApproved.selector);
        marketF.createListing(l);
    }

    function testMinPriceTooLow() public {
        switchSigner(dayo);
        nft.setApprovalForAll(address(marketF), true);
        l.price = 0;
        vm.expectRevert(MarketPlaceFacet.MinPriceTooLow.selector);
        marketF.createListing(l);
    }

    function testMinDeadline() public {
        switchSigner(dayo);
        nft.setApprovalForAll(address(marketF), true);
        vm.expectRevert(MarketPlaceFacet.DeadlineTooSoon.selector);
        marketF.createListing(l);
    }

    function testMinDuration() public {
        switchSigner(dayo);
        nft.setApprovalForAll(address(marketF), true);
        l.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(MarketPlaceFacet.MinDurationNotMet.selector);
        marketF.createListing(l);
    }

    function testValidSig() public {
        switchSigner(dayo);
        nft.setApprovalForAll(address(marketF), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyB
        );
        vm.expectRevert(MarketPlaceFacet.InvalidSignature.selector);
        marketF.createListing(l);
    }

    // EDIT LISTING
    function testEditNonValidListing() public {
        switchSigner(dayo);
        vm.expectRevert(MarketPlaceFacet.ListingNotExistent.selector);
        marketF.editListing(1, 0, false);
    }

    function testEditListingNotOwner() public {
        switchSigner(dayo);
        nft.setApprovalForAll(address(marketF), true);
        l.deadline = uint88(block.timestamp + 120 minutes);
        l.sig = constructSig(
            l.token,
            l.tokenId,
            l.price,
            l.deadline,
            l.lister,
            privKeyA
        );
        uint256 lId = marketF.createListing(l);
        switchSigner(motunrayo);
        vm.expectRevert(MarketPlaceFacet.NotOwner.selector);
        marketF.editListing(lId, 0, false);
    }

}
