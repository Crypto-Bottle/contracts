// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
pragma abicoder v2;

contract MockVRFCoordinator {
    function requestRandomWords(
        bytes32 /* _keyHash */,
        uint64 /* _subscriptionId */,
        uint16 /* _requestConfirmations */,
        uint32 /* _callbackGasLimit */,
        uint32 /* _numWords */
    ) external pure returns (uint256 requestId) {
        // This mock function simply returns a requestId of 1 for simplicity
        // In a real test, you would emit an event or have a way to trigger the callback
        // with generated random numbers for your contract to consume
        return 1;
    }
}
