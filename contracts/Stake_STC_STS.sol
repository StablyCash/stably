// SPDX-License-Identifier: MIT
pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./StakingRewards.sol";

contract Stake_STC_STS is StakingRewards {
    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken,
        address _stc_address,
        address _timelock_address,
        uint256 _pool_weight
    ) 
    StakingRewards(_owner, _rewardsDistribution, _rewardsToken, _stakingToken, _stc_address, _timelock_address, _pool_weight)
    public {}
}