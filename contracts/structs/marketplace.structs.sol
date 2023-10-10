// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct Listing {
   address token;
   uint256 tokenId;
   uint256 price;
   bytes sig;
   // Slot 4
   uint88 deadline;
   address lister;
   bool active;
}