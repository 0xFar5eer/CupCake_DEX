// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IAnyErc20Token.sol";

contract CupexStaking {
    uint256 constant SECONDS_IN_A_DAY = 86400;
    uint256 constant PERCENTAGE_INCREASE_IN_A_DAY = 10; // 10%
    uint256 constant PERCENTAGE_DENOMINATOR = 100;

    IAnyErc20Token immutable cupexToken;

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
        if (stake.amountStaked > 0) {
            unStake();
        }

        stake.amountStaked = _amount;
        stake.timestampStaked = block.timestamp;        

        cupexToken.burn(msg.sender, _amount);
    }

    function unStake() public {
        uint256 interest = _getStakeInterest();

        Stake storage stake = walletToStake[msg.sender];
        require(stake.amountStaked > 0, "User must have something staked");

        uint256 amountToWithdraw = stake.amountStaked + interest;
        stake.amountStaked = 0;
        stake.timestampStaked = 0;        

        cupexToken.mint(msg.sender, amountToWithdraw);
    }

    function getStakeInformation() public view returns (StakeInformation memory) {
        Stake storage stake = walletToStake[msg.sender];

        StakeInformation memory stakeInformation = StakeInformation({
            amountStaked: stake.amountStaked,
            timestampStaked: stake.timestampStaked,
            interest: _getStakeInterest()
        });

        return stakeInformation;
    }

    function _getStakeInterest() private view  returns (uint256) {
        Stake storage stake = walletToStake[msg.sender];
        if (stake.timestampStaked == 0) {
            return 0;
        }

        uint256 secondsPassed = block.timestamp - stake.timestampStaked;
        uint256 interest = (stake.amountStaked * secondsPassed * PERCENTAGE_INCREASE_IN_A_DAY) / (SECONDS_IN_A_DAY * PERCENTAGE_DENOMINATOR);

        return interest;
    }
}