# Offramp EURe bot Vyper smart contract

## offramp_bot_eth.vy

### deposit

This function deploys a bot contract using blueprint and create a loan.

| Key        | Type       | Description                             |
| ---------- | ---------- | --------------------------------------- |
| swap_infos | SwapInfo[] | swap info array to swap tokens on Curve |

### SwapInfo (struct)

This struct is to define swap information using Curve swap router.

| Key         | Type          | Description                                                                                              |
| ----------- | ------------- | -------------------------------------------------------------------------------------------------------- |
| route       | address[11]   | Array of tokens, pool or zap addresses that Curve swap router uses for exchange into DAI                 |
| swap_params | uint256[5][5] | Multidimensional array of [i, j, swap type, pool_type, n_coins] that Curve swap router uses for exchange |
| amount      | uint256       | The amount of input token (`route[0]`) to be sent                                                        |
| expected    | uint256       | The minimum DAI amount received after the final swap                                                     |
| pools       | address[5]    | Array of pools for swaps via zap contracts. This parameter is only needed for swap_type = 3.             |

## offramp_bot_eth.vy

### swap

This function swaps xDAI into EURe and sends to the depositor. Compass-EVM can run this function.

| Key        | Type    | Description                                                                              |
| ---------- | ------- | ---------------------------------------------------------------------------------------- |
| receiver   | address | Array of tokens, pool or zap addresses that Curve swap router uses for exchange into DAI |
| amount     | uint256 | The amount of DAI                                                                        |
| expected   | uint256 | The minimum EURe amount received after the final swap                                    |
| deposit_id | uint256 | Deposit id on the ETH Vyper contract                                                     |
| **return** | uint256 | EURe amount that the user receives                                                       |

### get_expected

This view function returns EURe amount from Curve exchange by DAI amount.

| Key        | Type    | Description                                 |
| ---------- | ------- | ------------------------------------------- |
| amount     | uint256 | Input DAI amount                            |
| **return** | uint256 | Expected EURe amount that the user receives |

### update_compass

Update Compass-EVM address.  This is run by Compass-EVM only.

| Key         | Type    | Description             |
| ----------- | ------- | ----------------------- |
| new_compass | address | New compass-evm address |

### update_refund_wallet

Update gas refund wallet address.  This is run by Compass-EVM only.

| Key               | Type    | Description               |
| ----------------- | ------- | ------------------------- |
| new_refund_wallet | address | New refund wallet address |

### update_fee

Update gas fee amount to pay.  This is run by Compass-EVM only.

| Key     | Type    | Description    |
| ------- | ------- | -------------- |
| new_fee | uint256 | New fee amount |

### set_paloma

Set Paloma CW address in bytes32.  This is run by Compass-EVM only and after setting paloma, the bot can start working.

### update_service_fee_collector

Update service fee collector address.  This is run by the original fee collector address. The address receives service fee from swapping.

| Key                       | Type    | Description                       |
| ------------------------- | ------- | --------------------------------- |
| new_service_fee_collector | address | New service fee collector address |
