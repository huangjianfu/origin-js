pragma solidity ^0.4.23;

import './ClaimHolder.sol';

/**
 * NOTE: This contract exists as a convenience for deploying an identity with
 * some 'pre-signed' claims. If you don't care about that, just use ClaimHolder
 * instead.
 */

contract ClaimHolderPresigned is ClaimHolder {

    constructor(
        address _ownerAddress,
        uint256[] _claimType,
        address[] _issuer,
        bytes _signature,
        bytes _data,
        uint256[] _offsets
    )
        KeyHolder(_ownerAddress)
        public
    {
        ClaimHolderLibrary.initializeClaims(
            keyHolderData,
            claims,
            _claimType,
            _issuer,
            _signature,
            _data,
            _offsets
        );
    }
}
