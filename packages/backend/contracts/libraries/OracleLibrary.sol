// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.28;

import { FixedPoint } from "./FixedPoint.sol";

import { PairV2 } from "../PairV2.sol";
import { PriceOracle } from "../PriceOracle.sol";

// library with helper methods for oracles that are concerned with computing average prices
library OracleLibrary {
	using FixedPoint for *;

	// helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
	function currentBlockTimestamp() internal view returns (uint32) {
		return uint32(block.timestamp % 2 ** 32);
	}

	// produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
	function currentCumulativePrices(
		address pair
	)
		internal
		view
		returns (
			uint price0Cumulative,
			uint price1Cumulative,
			uint32 blockTimestamp
		)
	{
		blockTimestamp = currentBlockTimestamp();
		price0Cumulative = PairV2(pair).price0CumulativeLast();
		price1Cumulative = PairV2(pair).price1CumulativeLast();

		// if time has elapsed since the last update on the pair, mock the accumulated price values
		(uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = PairV2(
			pair
		).getReserves();
		if (blockTimestampLast != blockTimestamp) {
			// subtraction overflow is desired
			uint32 timeElapsed = blockTimestamp - blockTimestampLast;
			// addition overflow is desired
			// counterfactual
			price0Cumulative +=
				uint(FixedPoint.fraction(reserve1, reserve0)._x) *
				timeElapsed;
			// counterfactual
			price1Cumulative +=
				uint(FixedPoint.fraction(reserve0, reserve1)._x) *
				timeElapsed;
		}
	}

	function oracleAddress(address router) external pure returns (address) {
		return
			address(
				uint160(
					uint256(
						keccak256(
							abi.encodePacked(
								hex"ff",
								router,
								keccak256(abi.encodePacked(router)),
								keccak256(type(PriceOracle).creationCode)
							)
						)
					)
				)
			);
	}
}
