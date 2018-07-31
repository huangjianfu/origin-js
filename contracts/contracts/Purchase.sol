pragma solidity 0.4.23;
import "./OnBehalfableLibrary.sol";

/// @title Purchase
/// @dev An purchase Origin Listing representing a purchase/booking
import "./Listing.sol";


/// @notice OnBehalfable
contract Purchase {

  /*
  * Events
  */

  event PurchaseChange(Stages stage);
  event PurchaseReview(address reviewer, address reviewee, Roles revieweeRole, uint8 rating, bytes32 ipfsHash);

  /*
  * Enum
  */

  enum Stages {
    AWAITING_PAYMENT, // Buyer hasn't paid full amount yet
    AWAITING_SELLER_APPROVAL, // Waiting on seller to approve purchase
    SELLER_REJECTED, // Seller has rejected purchase
    IN_ESCROW, // Payment has been received but not distributed to seller
    BUYER_PENDING, // Waiting for buyer to confirm receipt
    SELLER_PENDING, // Waiting for seller to confirm all is good
    IN_DISPUTE, // We are in a dispute
    REVIEW_PERIOD, // Time for reviews (only when transaction did not go through)
    COMPLETE // It's all over
  }

  enum Roles {
    BUYER,
    SELLER
  }

  /*
  * Storage
  */

  Stages internal internalStage = Stages.AWAITING_PAYMENT;

  Listing public listingContract; // listing that is being purchased
  address public buyer; // User who is buying. Seller is derived from listing
  uint public created;
  uint public buyerTimeout;
  uint public listingVersion;

  /*
  * Modifiers
  */

  modifier isSeller() {
    require(OnBehalfableLibrary.getSender_Purchase() == listingContract.owner());
    _;
  }

  modifier isBuyer() {
    require(OnBehalfableLibrary.getSender_Purchase() == buyer);
    _;
  }

  modifier atStage(Stages _stage) {
    require(stage() == _stage);
    _;
  }

  /*
  * Public functions
  */

  constructor(
    address _listingContractAddress,
    uint _listingVersion,
    address _buyer
  )
  public
  {
    buyer = _buyer;
    listingContract = Listing(_listingContractAddress);
    listingVersion = _listingVersion;
    created = now;
    emit PurchaseChange(internalStage);
  }

  function data()
  public
  view
  returns (Stages _stage, Listing _listingContract, address _buyer, uint _created, uint _buyerTimeout) {
      return (stage(), listingContract, buyer, created, buyerTimeout);
  }

  // Pay for listing
  // We used to limit this to buyer, but that prevents Listing contract from
  // paying
  function pay()
  public
  payable
  atStage(Stages.AWAITING_PAYMENT)
  {
    if (listingContract.needsSellerApproval()) {
      // Buyer (or their proxy) has paid enough to cover purchase
      setStage(Stages.AWAITING_SELLER_APPROVAL);
    } else if (listingContract.isApproved(this)) {
      setStage(Stages.IN_ESCROW);
    }
    // Possible that nothing happens, and contract just accumulates sent value
  }

  /// @notice OnBehalfable
  function sellerApprove()
  public
  isSeller
  atStage(Stages.AWAITING_SELLER_APPROVAL)
  {
    setStage(Stages.IN_ESCROW);
  }

  function sellerReject()
  public
  isSeller
  atStage(Stages.AWAITING_SELLER_APPROVAL)
  {
    setStage(Stages.SELLER_REJECTED);
  }

  /// @notice OnBehalfable
  function sellerConfirmShipped()
  public
  isSeller
  atStage(Stages.IN_ESCROW)
  {
      buyerTimeout = now + 21 days;
      setStage(Stages.BUYER_PENDING);
  }

  /// @notice OnBehalfable
  function buyerConfirmReceipt(uint8 _rating, bytes32 _ipfsHash)
  public
  isBuyer
  atStage(Stages.BUYER_PENDING)
  {
    // Checks
    require(_rating >= 1);
    require(_rating <= 5);

    // State changes
    setStage(Stages.SELLER_PENDING);

    // Events
    emit PurchaseReview(buyer, listingContract.owner(), Roles.SELLER, _rating, _ipfsHash);
  }

  /// @notice OnBehalfable
  function sellerCollectPayout(uint8 _rating, bytes32 _ipfsHash)
  public
  isSeller
  atStage(Stages.SELLER_PENDING)
  {
    // Checks
    require(_rating >= 1);
    require(_rating <= 5);

    // State changes
    setStage(Stages.COMPLETE);

    // Events
    emit PurchaseReview(listingContract.owner(), buyer, Roles.BUYER, _rating, _ipfsHash);

    // Transfers
    // Send contract funds to seller (ie owner of Listing)
    // Transfering money always needs to be the last thing we do, do avoid
    // rentrancy bugs. (Though here the seller would just be getting their own money)
    listingContract.owner().transfer(address(this).balance);
  }

  function openDispute()
  public
  {
    // Must be buyer or seller
    require(
      (OnBehalfableLibrary.getSender_Purchase() == buyer) ||
      (OnBehalfableLibrary.getSender_Purchase() == listingContract.owner())
    );

    // Must be in a valid stage
    require(
      (stage() == Stages.BUYER_PENDING) ||
      (stage() == Stages.SELLER_PENDING)
    );

    setStage(Stages.IN_DISPUTE);

    // TODO: Create a dispute contract?
    // Right now there's no way to exit this state.
  }

  function stage()
  public
  view
  returns (Stages _stage)
  {
    if (internalStage == Stages.BUYER_PENDING) {
      if (now > buyerTimeout) {
        return Stages.SELLER_PENDING;
      }
    }
    return internalStage;
  }

  function setStage(Stages _stage)
  internal
  {
    internalStage = _stage;
    emit PurchaseChange(_stage);
  }
  event UnMatchedData(address _contract, address _nonce_tracker, uint256 _nonce);
  event UnMatchedHash(bytes32 hash);

    
    function proxy_sellerApprove(address __sender, uint8 __v, bytes32 __r, bytes32 __s, address __ntracker, uint256 __nonce)  public {
      bytes32 in_hash = keccak256("sellerApprove", address(this), __ntracker, __nonce);
      if (OnBehalfableLibrary.hashCheck(__sender, __v, __r, __s, in_hash) && NonceTracker(__ntracker).setNonce(__sender, __nonce))
      {
        sellerApprove();
      }
      else
      {
        emit UnMatchedData(address(this), __ntracker, __nonce);
        emit UnMatchedHash(in_hash);
      }
    }
      
    function proxy_sellerConfirmShipped(address __sender, uint8 __v, bytes32 __r, bytes32 __s, address __ntracker, uint256 __nonce)  public {
      bytes32 in_hash = keccak256("sellerConfirmShipped", address(this), __ntracker, __nonce);
      if (OnBehalfableLibrary.hashCheck(__sender, __v, __r, __s, in_hash) && NonceTracker(__ntracker).setNonce(__sender, __nonce))
      {
        sellerConfirmShipped();
      }
      else
      {
        emit UnMatchedData(address(this), __ntracker, __nonce);
        emit UnMatchedHash(in_hash);
      }
    }
      
    function proxy_buyerConfirmReceipt(address __sender, uint8 __v, bytes32 __r, bytes32 __s, address __ntracker, uint256 __nonce, uint8 _rating, bytes32 _ipfsHash)  public {
      bytes32 in_hash = keccak256("buyerConfirmReceipt", address(this), __ntracker, __nonce, _rating, _ipfsHash);
      if (OnBehalfableLibrary.hashCheck(__sender, __v, __r, __s, in_hash) && NonceTracker(__ntracker).setNonce(__sender, __nonce))
      {
        buyerConfirmReceipt(_rating, _ipfsHash);
      }
      else
      {
        emit UnMatchedData(address(this), __ntracker, __nonce);
        emit UnMatchedHash(in_hash);
      }
    }
      
    function proxy_sellerCollectPayout(address __sender, uint8 __v, bytes32 __r, bytes32 __s, address __ntracker, uint256 __nonce, uint8 _rating, bytes32 _ipfsHash)  public {
      bytes32 in_hash = keccak256("sellerCollectPayout", address(this), __ntracker, __nonce, _rating, _ipfsHash);
      if (OnBehalfableLibrary.hashCheck(__sender, __v, __r, __s, in_hash) && NonceTracker(__ntracker).setNonce(__sender, __nonce))
      {
        sellerCollectPayout(_rating, _ipfsHash);
      }
      else
      {
        emit UnMatchedData(address(this), __ntracker, __nonce);
        emit UnMatchedHash(in_hash);
      }
    }
      
    
}
