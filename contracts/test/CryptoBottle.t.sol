// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma abicoder v2;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CryptoCuvee} from "../src/CryptoBottle.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockVRFCoordinator {
    function requestRandomWords(
        bytes32, /* _keyHash */
        uint64, /* _subscriptionId */
        uint16, /* _requestConfirmations */
        uint32, /* _callbackGasLimit */
        uint32 /* _numWords */
    ) external pure returns (uint256 requestId) {
        // This mock function simply returns a requestId of 1 for simplicity
        // In a real test, you would emit an event or have a way to trigger the callback
        // with generated random numbers for your contract to consume
        return 1;
    }
}

contract MockCryptoCuvee is CryptoCuvee {   
}