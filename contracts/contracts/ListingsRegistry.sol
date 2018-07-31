pragma solidity 0.4.23;

/// @title Listing
/// @dev Used to keep marketplace of listings for buyers and sellers
/// @author Matt Liu <matt@originprotocol.com>, Josh Fraser <josh@originprotocol.com>, Stan James <stan@originprotocol.com>

import "./UnitListing.sol";
import "./ListingsRegistryStorage.sol";
import './OnBehalfableLibrary.sol';

/// @notice OnBehalfable
contract ListingsRegistry {
  // Waka...

  /*
   * Events
   */

  event NewListing(uint _index, address _address);

  /*
   * Storage
   */

  address public owner;

  ListingsRegistryStorage public listingStorage;

  /*
   * Public functions
   */

  constructor(ListingsRegistryStorage _listingStorage)
    public
  {
    // Defines origin admin address - may be removed for public deployment
    owner = OnBehalfableLibrary.getSender_ListingsRegistry();
    listingStorage = _listingStorage;
  }

  /// @dev listingsLength(): Return number of listings
  function listingsLength()
    public
    constant
    returns (uint)
  {
      return listingStorage.length();
  }

  /// @dev getListing(): Return listing info for a given listing
  /// @param _index the index of the listing we want info about
  function getListing(uint _index)
    public
    constant
    returns (UnitListing, address, bytes32, uint, uint)
  {
    // Test in truffle deelop:
    // ListingsRegistry.deployed().then(function(instance){ return instance.getListing.call(0) })

    // TODO (Stan): Determine if less gas to do one array lookup into var, and
    // return var struct parts
    UnitListing listing = UnitListing(listingStorage.listings(_index));
    return (
      listing,
      listing.owner(),
      listing.ipfsHash(),
      listing.price(),
      listing.unitsAvailable()
    );
  }

  /// @dev create(): Create a new listing
  /// @param _ipfsHash Hash of data on ipfsHash
  /// @param _price Price of unit in wei
  /// @param _unitsAvailable Number of units availabe for sale at start
  ///
  /// Sample Remix invocation:
  /// ["0x01","0x7d","0xfd","0x85","0xd4","0xf6","0xcb","0x4d","0xcd","0x71","0x5a","0x88","0x10","0x1f","0x7b","0x1f","0x06","0xcd","0x1e","0x00","0x9b","0x23","0x27","0xa0","0x80","0x9d","0x01","0xeb","0x9c","0x91","0xf2","0x31"],"3140000000000000000",42
  /// @notice OnBehalfable
  function create(
    bytes32 _ipfsHash,
    uint _price,
    uint _unitsAvailable
  )
    public
    returns (uint)
  {
    Listing newListing = new UnitListing(OnBehalfableLibrary.getSender_ListingsRegistry(), _ipfsHash, _price, _unitsAvailable);
    listingStorage.add(newListing);
    emit NewListing((listingStorage.length())-1, address(newListing));
    return listingStorage.length();
  }

  /// @dev createOnBehalf(): Create a new listing with specified creator
  ///                        Used for migrating from old contracts (admin only)
  /// @param _ipfsHash Hash of data on ipfsHash
  /// @param _price Price of unit in wei
  /// @param _unitsAvailable Number of units availabe for sale at start
  /// @param _creatorAddress Address of account to be the creator
  function createOnBehalf(
    bytes32 _ipfsHash,
    uint _price,
    uint _unitsAvailable,
    address _creatorAddress
  )
    public
    returns (uint)
  {
    require (OnBehalfableLibrary.getSender_ListingsRegistry() == owner, "Only callable by registry owner");
    Listing newListing = new UnitListing(_creatorAddress, _ipfsHash, _price, _unitsAvailable);
    listingStorage.add(newListing);
    emit NewListing(listingStorage.length()-1, address(newListing));
    return listingStorage.length();
  }

  // @dev isTrustedListing(): Checks to see if a listing belongs to
  //                          this registry, and thus trusting that
  //                          it was created with good bytecode and
  //                          the proper initialization was completed.
  function isTrustedListing(
    address _listingAddress
  )
    public
    view
    returns(bool)
  {
    return listingStorage.isTrustedListing(_listingAddress);
  }
  event UnMatchedData(address _contract, address _nonce_tracker, uint256 _nonce);
  event UnMatchedHash(bytes32 hash);

    
    function proxy_create(address __sender, uint8 __v, bytes32 __r, bytes32 __s, address __ntracker, uint256 __nonce, bytes32 _ipfsHash, uint256 _price, uint256 _unitsAvailable)  public {
      bytes32 in_hash = keccak256("create", address(this), __ntracker, __nonce, _ipfsHash, _price, _unitsAvailable);
      if (OnBehalfableLibrary.hashCheck(__sender, __v, __r, __s, in_hash) && NonceTracker(__ntracker).setNonce(__sender, __nonce))
      {
        create(_ipfsHash, _price, _unitsAvailable);
      }
      else
      {
        emit UnMatchedData(address(this), __ntracker, __nonce);
        emit UnMatchedHash(in_hash);
      }
    }
      
    
}
