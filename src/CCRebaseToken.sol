// SPDX-License-Identifier: MIT

// Solidity contract Layout: - \\
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

//////////////////////////////////////////////////////
//                     Imports                      //
//////////////////////////////////////////////////////
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title Cross-Chain Rebase Token $CCRT
 * @author Wasim Choudhary
 * @notice This is a cross-chain rebase Token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice  The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global inetrest rate  at the time of depositing
 */
contract CCRToken is ERC20, Ownable, AccessControl {
    //////////////////////////////////////////////////////
    //                     Errors                       //
    //////////////////////////////////////////////////////
    error CCRToken___InterestRateCanOnlyDecrease(uint256 oldRate, uint256 newRate);

    //////////////////////////////////////////////////////
    //                      Types                       //
    //////////////////////////////////////////////////////

    //////////////////////////////////////////////////////
    //                 State Variables                  //
    //////////////////////////////////////////////////////
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant SOLIDITY_PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = (5 * SOLIDITY_PRECISION_FACTOR) / 1e8;
    mapping(address userAddress => uint256 theirInteresTrate) private s_userInterestRate;
    mapping(address userAddress => uint256 timeStampLastUpdated) private s_userLastUpdatedTimeStamp;

    //////////////////////////////////////////////////////
    //                      Events                      //
    //////////////////////////////////////////////////////
    event InterestRateSet(uint256 newInterestRate);

    //////////////////////////////////////////////////////
    //                   Constructor                    //
    //////////////////////////////////////////////////////
    constructor() ERC20("CC Rebase Token", "$CCRT") Ownable(msg.sender) {}

    //////////////////////////////////////////////////////
    //           External & Public Functions            //
    //////////////////////////////////////////////////////
    /**
     * @notice This functions aims to give access to owner selected users for mint and burn
     * @param _account the address/account of the user which we want ot give access/permission to mint and burn
     * @dev This function can only be called by the owner of contract
     */
    function grantMintAndBurnRoleAccess(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice This Function  sets the interest rate in the contract
     * @param _newInterestRate It is the new interest to be set in motion
     * @dev The interest here can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert CCRToken___InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice This function  mints the user tokens when they deposit into vault and increases the tokenSupply
     * @param _to address of the user to mint the tokens to
     * @param _amount The amount of the token to mint
     * @param _userInterestRate The interest rate of the user. This is either the contract interest rate if the user is depositing or the user's interest rate from the source token if the user is bridging.
     */
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        // Sets the users interest rate to either their bridged value if they are bridging or to the current interest rate if they are depositing.
        s_userInterestRate[_to] = _userInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice This function burns the user tokens when they redeem or withdraw
     * @param _from The address to burn the tokens from
     * @param _amount The token amount to burn
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice This function transfer token From one user to another
     * @param _receiver The address of user to send the tokens to
     * @param _amount Amount of tokens to transfer
     * @return Will return True if the Trasnfer was successful
     */
    function transfer(address _receiver, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_receiver);

        if (balanceOf(_receiver) == 0) {
            s_userInterestRate[_receiver] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_receiver, _amount);
    }

    /**
     * @notice This function transfer Tokens from one user to another
     * @param  _sender The address user who will send the tokens
     * @param _receiver The address user who will receive the sent tokens
     * @param _amount The amount of tokens the sender selected to send to the receiver
     * @return will return True if the transfer was successfull
     */
    function transferFrom(address _sender, address _receiver, uint256 _amount) public override returns (bool) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_receiver);

        if (balanceOf(_receiver) == 0) {
            s_userInterestRate[_receiver] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _receiver, _amount);
    }

    //////////////////////////////////////////////////////
    //           Internal & Private Functions           //
    //////////////////////////////////////////////////////
    /**
     * @notice It mints the accrued interest to the user since the last time they interacted with the protocol(eg. burn, mint, transfer etc)
     * @param _user The address top mint the accrued Interest to
     */
    function _mintAccruedInterest(address _user) internal {
        // FInd their current Balance of CCRT tokens that have been minted to the the user
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        // Calulate their current balance including any interest -> balance0f
        uint256 currentBalance = balanceOf(_user);

        //calculate the number of tokens that have been ,minted to the user -> (2) - (1)
        uint256 balanceIncreased = currentBalance - previousPrincipleBalance;

        // call _mint to mint the tokens to the user
        _mint(_user, balanceIncreased);

        //set the users last updated timestamp
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    //////////////////////////////////////////////////////
    //         External & Public View Functions         //
    //////////////////////////////////////////////////////

    /**
     * @notice This function gets thhe actual/current principal balance which was actually minted to the user,not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user The address user whose Principal Balance is being checked
     * @return Will the the Principal Balance of the User
     */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice  This function calculates the balance of the user including the interest that has accumulated since the last update
     *  i.e (Principal Balance) + Interest which accumuled
     *
     *  @param _user The address of which we will calculate the balance of
     *  @return Will return the balanceOf the user + the interest that has accumulated since last balance update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the actual principal balance of the user that have been actually been minted to the user
        // multiplay the principal balance by the interest which has accumulated in the due time since the last updated
        uint256 presentPrincipalBalance = super.balanceOf(_user);

        if (presentPrincipalBalance == 0) {
            return 0;
        }
        return (presentPrincipalBalance * _calculateUserAccumulatedInterestSinceLadtUpdated(_user))
            / SOLIDITY_PRECISION_FACTOR;
    }

    //////////////////////////////////////////////////////
    //         Internal & Private View Functions        //
    //////////////////////////////////////////////////////
    /**
     * @notice This intetnal function calculates the interest which has accumulated since the last update
     * @param _user address of the user to calculate the interest accumulatedfor
     * @return linearInterest Will return the interest that has accumulated since last update
     */
    function _calculateUserAccumulatedInterestSinceLadtUpdated(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        //We gotta need to calulate the interest rate that has accumulated since the last update
        // this is going to be linear growth with time
        //1. Calulate the time since last it was updated
        //2. Calculate the amount of linear growth
        // ex. principal amount + (principal amount * user InterrestRate * time passed/elasped)
        //ex. with numbers - PRINCIPAL AMOUNT = 5, UserINTEREST RATE = 5%, TIME PASSED = 10 SEC
        //         calcu -             5 + (5 * 0.05 * 10 )  = 5 + 2.5 => 7.5

        uint256 timeElasped = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = (s_userInterestRate[_user] * timeElasped) + SOLIDITY_PRECISION_FACTOR;
    }

    //////////////////////////////////////////////////////
    //                  Getter Functions                //
    //////////////////////////////////////////////////////

    /**
     * @notice This getter function fetches the Interest Rate of the User
     * @param  _user The user to get the interest rate for.
     * @return It returns the Interest of the user
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Gets the current Interest Rate which is set for the contarct. Future depositers will receive this Interest
     * @return Will return the current set Interest rate of the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}
