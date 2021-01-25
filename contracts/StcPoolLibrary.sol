// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";


library StcPoolLibrary {
    using SafeMath for uint256;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // ================ Structs ================
    // Needed to lower stack size
    struct MintFF_Params {
        uint256 mint_fee; 
        uint256 sts_price_usd; 
        uint256 stc_price_usd; 
        uint256 col_price_usd;
        uint256 sts_amount;
        uint256 collateral_amount;
        uint256 collateral_token_balance;
        uint256 pool_ceiling;
        uint256 col_ratio;
    }

    struct BuybackSTS_Params {
        uint256 excess_collateral_dollar_value_d18;
        uint256 sts_price_usd;
        uint256 col_price_usd;
        uint256 STS_amount;
    }

    // ================ Functions ================

    function calcMint1t1STC(uint256 col_price, uint256 mint_fee, uint256 collateral_amount_d18) public pure returns (uint256) {
        uint256 col_price_usd = col_price;
        uint256 c_dollar_value_d18 = (collateral_amount_d18.mul(col_price_usd)).div(1e6);
        return c_dollar_value_d18.sub((c_dollar_value_d18.mul(mint_fee)).div(1e6));
    }

    function calcMintAlgorithmicSTC(uint256 mint_fee, uint256 sts_price_usd, uint256 sts_amount_d18) public pure returns (uint256) {
        uint256 sts_dollar_value_d18 = sts_amount_d18.mul(sts_price_usd).div(1e6);
        return sts_dollar_value_d18.sub((sts_dollar_value_d18.mul(mint_fee)).div(1e6));
    }

    // Must be internal because of the struct
    function calcMintFractionalSTC(MintFF_Params memory params) internal pure returns (uint256, uint256) {
        // Since solidity truncates division, every division operation must be the last operation in the equation to ensure minimum error
        // The contract must check the proper ratio was sent to mint STC. We do this by seeing the minimum mintable STC based on each amount 
        uint256 sts_dollar_value_d18;
        uint256 c_dollar_value_d18;
        
        // Scoping for stack concerns
        {    
            // USD amounts of the collateral and the STS
            sts_dollar_value_d18 = params.sts_amount.mul(params.sts_price_usd).div(1e6);
            c_dollar_value_d18 = params.collateral_amount.mul(params.col_price_usd).div(1e6);

        }
        uint calculated_sts_dollar_value_d18 = 
                    (c_dollar_value_d18.mul(1e6).div(params.col_ratio))
                    .sub(c_dollar_value_d18);

        uint calculated_sts_needed = calculated_sts_dollar_value_d18.mul(1e6).div(params.sts_price_usd);

        return (
            (c_dollar_value_d18.add(calculated_sts_dollar_value_d18)).sub(((c_dollar_value_d18.add(calculated_sts_dollar_value_d18)).mul(params.mint_fee)).div(1e6)),
            calculated_sts_needed
        );
    }

    function calcRedeem1t1STC(uint256 col_price_usd, uint256 STC_amount, uint256 redemption_fee) public pure returns (uint256) {
        uint256 collateral_needed_d18 = STC_amount.mul(1e6).div(col_price_usd);
        return collateral_needed_d18.sub((collateral_needed_d18.mul(redemption_fee)).div(1e6));
    }

    // Must be internal because of the struct
    function calcBuyBackSTS(BuybackSTS_Params memory params) internal pure returns (uint256) {
        // If the total collateral value is higher than the amount required at the current collateral ratio then buy back up to the possible STS with the desired collateral
        require(params.excess_collateral_dollar_value_d18 > 0, "No excess collateral to buy back!");

        // Make sure not to take more than is available
        uint256 sts_dollar_value_d18 = params.STS_amount.mul(params.sts_price_usd).div(1e6);
        require(sts_dollar_value_d18 <= params.excess_collateral_dollar_value_d18, "You are trying to buy back more than the excess!");

        // Get the equivalent amount of collateral based on the market value of STS provided 
        uint256 collateral_equivalent_d18 = sts_dollar_value_d18.mul(1e6).div(params.col_price_usd);
        //collateral_equivalent_d18 = collateral_equivalent_d18.sub((collateral_equivalent_d18.mul(params.buyback_fee)).div(1e6));

        return (
            collateral_equivalent_d18
        );

    }


    // Returns value of collateral that must increase to reach recollateralization target (if 0 means no recollateralization)
    function recollateralizeAmount(uint256 total_supply, uint256 global_collateral_ratio, uint256 global_collat_value) public pure returns (uint256) {
        uint256 target_collat_value = total_supply.mul(global_collateral_ratio).div(1e6); // We want 18 decimals of precision so divide by 1e6; total_supply is 1e18 and global_collateral_ratio is 1e6
        // Subtract the current value of collateral from the target value needed, if higher than 0 then system needs to recollateralize
        uint256 recollateralization_left = target_collat_value.sub(global_collat_value); // If recollateralization is not needed, throws a subtraction underflow
        return(recollateralization_left);
    }

    function calcRecollateralizeSTCInner(
        uint256 collateral_amount, 
        uint256 col_price,
        uint256 global_collat_value,
        uint256 stc_total_supply,
        uint256 global_collateral_ratio
    ) public pure returns (uint256, uint256) {
        uint256 collat_value_attempted = collateral_amount.mul(col_price).div(1e6);
        uint256 effective_collateral_ratio = global_collat_value.mul(1e6).div(stc_total_supply); //returns it in 1e6
        uint256 recollat_possible = (global_collateral_ratio.mul(stc_total_supply).sub(stc_total_supply.mul(effective_collateral_ratio))).div(1e6);
        uint256 amount_to_recollat;
        if(collat_value_attempted <= recollat_possible){
            amount_to_recollat = collat_value_attempted;
        } else {
            amount_to_recollat = recollat_possible;
        }

        return (amount_to_recollat.mul(1e6).div(col_price), amount_to_recollat);

    }

}