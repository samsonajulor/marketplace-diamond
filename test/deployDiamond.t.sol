// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/MarketPlaceFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721Facet.sol";


import "./helpers/DiamondUtils.sol";
import {
    Helpers
} from "./helpers/MarketPlaceUtils.sol";
// import "../contracts/ERC721Mock.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    MarketPlaceFacet marketF;
    ERC721Facet erc721F;

    Listing l;
    // OurNFT nft;

    uint256 privKeyA = uint256(keccak256(abi.encodePacked("dayo")));
    uint256 privKeyB = uint256(keccak256(abi.encodePacked("motun")));
    address dayo = vm.addr(privKeyA);
    address motunrayo = vm.addr(privKeyB);
    address tope = address(0x3333);
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

    function setUp() public {
        vm.deal(dayo, 4 ether);
        vm.deal(motunrayo, 4 ether);
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet), "MYNFT", "nft");
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        marketF = new MarketPlaceFacet();
        erc721F = new ERC721Facet();
        // nft = new OurNFT();



        l = Listing({
            token: address(erc721F),
            tokenId: 1,
            price: 1 ether,
            sig: bytes(""),
            deadline: 0,
            lister: address(0),
            active: false
        });

        // mint NFT
        erc721F.mint(address(0x1111), 1);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

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

        cut[3] = (
            FacetCut({
                facetAddress: address(erc721F),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC721Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
        // vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}

    /// tests for erc721
    function testName() public{
        assertEq(erc721F.getName(), 'MYNFT');
    }


    /// Tests for MarketPlace
    function testOwnerCannotCreateListing() public {
        l.lister = dayo;
        vm.startPrank(address(diamond));

        vm.expectRevert(MarketPlaceFacet.NotOwner.selector);
        marketF.createListing(l);
    }

    function testNonApprovedNFT() public {
        // start prank with creator
        vm.startPrank(address(diamond));
        vm.expectRevert(MarketPlaceFacet.NotApproved.selector);
        marketF.createListing(l);
    }

    function testMinPriceTooLow() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
        l.price = 0;
        vm.expectRevert(MarketPlaceFacet.MinPriceTooLow.selector);
        marketF.createListing(l);
    }

    function testMinDeadline() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
        vm.expectRevert(MarketPlaceFacet.DeadlineTooSoon.selector);
        marketF.createListing(l);
    }

    function testMinDuration() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
        l.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(MarketPlaceFacet.MinDurationNotMet.selector);
        marketF.createListing(l);
    }

    function testValidSig() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        vm.startPrank(dayo);
        vm.expectRevert(MarketPlaceFacet.ListingNotExistent.selector);
        marketF.editListing(1, 0, false);
    }

    function testEditListingNotOwner() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        vm.startPrank(motunrayo);
        vm.expectRevert(MarketPlaceFacet.NotOwner.selector);
        marketF.editListing(lId, 0, false);
    }

    function testEditListing() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        marketF.editListing(lId, 0.01 ether, false);

        Listing memory t = marketF.getListing(lId);
        assertEq(t.price, 0.01 ether);
        assertEq(t.active, false);
    }

    // EXECUTE LISTING
    function testExecuteNonValidListing() public {
        vm.startPrank(dayo);
        vm.expectRevert(MarketPlaceFacet.ListingNotExistent.selector);
        marketF.executeListing(1);
    }

    function testExecuteExpiredListing() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
    }

    function testExecuteListingNotActive() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        marketF.editListing(lId, 0.01 ether, false);
        vm.expectRevert(MarketPlaceFacet.ListingNotActive.selector);
        marketF.executeListing(lId);
    }

    function testExecutePriceNotMet() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketPlaceFacet.PriceNotMet.selector,
                l.price - 0.9 ether
            )
        );
        marketF.executeListing{value: 0.9 ether}(lId);
    }


    function testExecute() public {
        vm.startPrank(dayo);
        erc721F.setApprovalForAll(address(marketF), true);
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
        vm.startPrank(motunrayo);
        uint256 dayoBalanceBefore = dayo.balance;

        marketF.executeListing{value: l.price}(lId);

        Listing memory t = marketF.getListing(lId);
        assertEq(t.price, 1 ether);
        assertEq(t.active, false);

        assertEq(ERC721(l.token).ownerOf(l.tokenId), motunrayo);
    }
      function testMint() public {
         vm.startPrank(address(0x1111));
        ERC721Facet(address(diamond)).mint(address(0x1111), 1);
        assertEq(ERC721Facet(address(diamond)).balanceOf(address(0x1111)), 1);
    }
    function testBalanceOf() public {
         vm.startPrank(address(0x1111));
        ERC721Facet(address(diamond)).mint(address(0x1111), 1);
        assertEq(ERC721Facet(address(diamond)).balanceOf(address(0x1111)), 1);
    }
    // function testBurn() public {
    //    vm.startPrank(address(0x1111));
    //     ERC721Facet(address(diamond)).mint(address(0x1111), 1);
    //     ERC721Facet(address(diamond)).burn (1); 
    // }
    function testTransferFrom() public {
         vm.startPrank(address(0x1111));
        ERC721Facet(address(diamond)).mint(address(0x1111), 1);
        ERC721Facet(address(diamond)).approve(address(diamond), 1);
        vm.startPrank(address(diamond));
        ERC721Facet(address(diamond)).transferFrom(address(0x1111), address(0x2222), 1);
    }
    function testApprove() public {
             vm.startPrank(address(0x1111));
        ERC721Facet(address(diamond)).mint(address(0x1111), 1);
        ERC721Facet(address(diamond)).approve(address(0x2222), 1);
    }
    function testSafeTransferFrom() public {
        vm.startPrank(address(0xA003A9A2E305Ff215F29fC0b7b4E2bb5a8C2F3e1));
        ERC721Facet(address(diamond)).mint(address(0xA003A9A2E305Ff215F29fC0b7b4E2bb5a8C2F3e1), 1);
        ERC721Facet(address(diamond)).approve(address(diamond), 1);
        vm.startPrank(address(diamond));
        ERC721Facet(address(diamond)).transferFrom(address(0xA003A9A2E305Ff215F29fC0b7b4E2bb5a8C2F3e1), address(0x2222), 1);
    }
    function testOwnerOf() public {
        vm.startPrank(address(0x1111));
     ERC721Facet(address(diamond)).mint(address(0x1111), 1);  
     ERC721Facet(address(diamond)).ownerOf(1);
    }

}
