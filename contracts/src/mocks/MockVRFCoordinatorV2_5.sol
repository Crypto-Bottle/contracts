// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface BlockhashStoreInterface {
    function getBlockhash(uint256 blockNum) external view returns (bytes32);
}

contract MockVRFCoordinatorV2_5 {
    BlockhashStoreInterface public immutable BLOCKHASH_STORE;

    uint16 public constant MAX_REQUEST_CONFIRMATIONS = 200;
    uint32 public constant MAX_NUM_WORDS = 500;

    mapping(bytes32 => bool) public s_provingKeys;
    bytes32[] public s_provingKeyHashes;
    mapping(uint256 => bytes32) public s_requestCommitments;

    event ProvingKeyRegistered(bytes32 keyHash, uint64 maxGas);
    event ProvingKeyDeregistered(bytes32 keyHash, uint64 maxGas);
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        address indexed sender
    );
    event RandomWordsFulfilled(
        uint256 indexed requestId,
        uint256 outputSeed,
        uint256 indexed subId,
        uint96 payment,
        bool nativePayment,
        bool success
    );

    constructor(address blockhashStore) {
        BLOCKHASH_STORE = BlockhashStoreInterface(blockhashStore);
    }

    function registerProvingKey(bytes32 keyHash) external {
        require(!s_provingKeys[keyHash], "ProvingKeyAlreadyRegistered");
        s_provingKeys[keyHash] = true;
        s_provingKeyHashes.push(keyHash);
        emit ProvingKeyRegistered(keyHash, 0);
    }

    function deregisterProvingKey(bytes32 keyHash) external {
        require(s_provingKeys[keyHash], "NoSuchProvingKey");
        delete s_provingKeys[keyHash];
        for (uint256 i = 0; i < s_provingKeyHashes.length; i++) {
            if (s_provingKeyHashes[i] == keyHash) {
                s_provingKeyHashes[i] = s_provingKeyHashes[s_provingKeyHashes.length - 1];
                s_provingKeyHashes.pop();
                break;
            }
        }
        emit ProvingKeyDeregistered(keyHash, 0);
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint256 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        require(minimumRequestConfirmations <= MAX_REQUEST_CONFIRMATIONS, "InvalidRequestConfirmations");
        require(callbackGasLimit <= 2_500_000, "GasLimitTooBig"); // Arbitrary limit for this mock
        require(numWords <= MAX_NUM_WORDS, "NumWordsTooBig");

        requestId = uint256(keccak256(abi.encode(keyHash, msg.sender, subId, block.number)));
        uint256 preSeed = uint256(keccak256(abi.encode(requestId, blockhash(block.number - 1))));
        
        s_requestCommitments[requestId] = keccak256(abi.encode(
            requestId,
            block.number,
            subId,
            callbackGasLimit,
            numWords,
            msg.sender
        ));

        emit RandomWordsRequested(
            keyHash,
            requestId,
            preSeed,
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords,
            msg.sender
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(s_requestCommitments[requestId] != 0, "NoCorrespondingRequest");
        delete s_requestCommitments[requestId];

        emit RandomWordsFulfilled(requestId, randomWords[0], 0, 0, false, true);
    }
}
