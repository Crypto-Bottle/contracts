// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma abicoder v2;

import {CryptoCuvee} from "./CryptoBottle.sol";

contract MockCryptoCuvee is CryptoCuvee {
    function testIncreaseBalance(address _user, uint128 value) public {
        _increaseBalance(_user, value);
    }
}
