//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface CTokenInterface {
     function mintToken() external;
     function redeemToken() external;
     function borrow() external;
     function repayBorrow() external;
}