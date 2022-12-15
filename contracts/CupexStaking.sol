// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IAnyErc20Token.sol";

contract CupexStaking {
    uint256 constant SECONDS_IN_A_DAY = 86400;
    uint256 constant PERCENTAGE_INCREASE_IN_A_DAY = 10; // 10% daily inflation
    uint256 constant PERCENTAGE_DENOMINATOR = 100;

    // staked token never changes its value => immutable
    IAnyErc20Token immutable cupexToken;

    // stores and returns stake struct for given wallet address
    mapping(address => Stake) public walletToStake;

    struct Stake {
        uint256 timestampStaked;
        uint256 amountStaked;
    }

    struct StakeInformation {
        uint256 timestampStaked;
        uint256 amountStaked;
        uint256 interest;
    }
    
    constructor(IAnyErc20Token _cupexToken) {
        cupexToken = _cupexToken;
    }

    function createStake(uint256 _amount) public {
        Stake storage stake = walletToStake[msg.sender];

        // unstaking (if needed) before creating new stake
        if (stake.amountStaked > 0) {
            unStake();
        }

        // updating storage variables
        stake.amountStaked = _amount;
        stake.timestampStaked = block.timestamp;        

        // burning the token from the user
        // in production some protection must be added
        // right now anyone can burn/mint tokens
        cupexToken.burn(msg.sender, _amount);
    }

    function unStake() public {
        Stake storage stake = walletToStake[msg.sender];

        // early exit if nothing staked
        if (stake.amountStaked == 0) {
            return;
        }

        // getting amount of tokens user must be getting
        uint256 interest = _getStakeInterest();
        uint256 amountToWithdraw = stake.amountStaked + interest;

        // updating storage variables
        stake.amountStaked = 0;
        stake.timestampStaked = 0;        

        // minting the tokens to the user
        // in production some protection must be added
        // right now anyone can burn/mint tokens
        cupexToken.mint(msg.sender, amountToWithdraw);
    }

    // frontend convenience function
    function getStakeInformation() public view returns (StakeInformation memory) {
        Stake storage stake = walletToStake[msg.sender];

        StakeInformation memory stakeInformation = StakeInformation({
            amountStaked: stake.amountStaked,
            timestampStaked: stake.timestampStaked,
            interest: _getStakeInterest()
        });

        return stakeInformation;
    }

    // simple model of interest 10% per day token inflation
    function _getStakeInterest() private view  returns (uint256) {
        Stake storage stake = walletToStake[msg.sender];

        // early exit if nothing staked
        if (stake.amountStaked == 0) {
            return 0;
        }

        // calculating interest
        uint256 secondsPassed = block.timestamp - stake.timestampStaked;
        uint256 interest = (stake.amountStaked * secondsPassed * PERCENTAGE_INCREASE_IN_A_DAY) / (SECONDS_IN_A_DAY * PERCENTAGE_DENOMINATOR);

        return interest;
    }
}