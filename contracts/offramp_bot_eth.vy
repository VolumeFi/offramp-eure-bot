#pragma version 0.4.0
#pragma optimize gas
#pragma evm-version cancun
"""
@title Offramp TWAP Bot on ETH
@license Apache 2.0
@author Volume.finance
"""

struct SwapInfo:
    route: address[11]
    swap_params: uint256[5][5]
    amount: uint256
    expected: uint256
    pools: address[5]

interface CurveSwapRouter:
    def exchange(
        _route: address[11],
        _swap_params: uint256[5][5],
        _amount: uint256,
        _expected: uint256,
        _pools: address[5]
    ) -> uint256: payable

interface ERC20:
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool: nonpayable

interface DaiBridge:
    def relayTokens(_receiver: address, _amount: uint256): nonpayable

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE # Virtual ETH
DAI: immutable(address)
BRIDGE: immutable(address)
ROUTER: immutable(address)
MAX_SIZE: constant(uint256) = 8
OPPOSITE: public(immutable(address))
next_deposit: public(uint256)

event Deposited:
    deposit_id: uint256
    token0: address
    amount0: uint256
    amount1: uint256
    depositor: address
    number_trades: uint256
    interval: uint256

@deploy
def __init__(dai: address, bridge: address, router: address, opposite: address):
    ROUTER = router
    DAI = dai
    BRIDGE = bridge
    OPPOSITE = opposite

@internal
def _safe_approve(_token: address, _spender: address, _value: uint256):
    assert extcall ERC20(_token).approve(_spender, _value, default_return_value=True), "Failed approve"

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    assert extcall ERC20(_token).transferFrom(_from, _to, _value, default_return_value=True), "Failed transferFrom"

@external
@payable
@nonreentrant
def deposit(swap_infos: DynArray[SwapInfo, MAX_SIZE], number_trades: uint256, interval: uint256):
    _value: uint256 = msg.value
    _next_deposit: uint256 = self.next_deposit
    dai_amount: uint256 = 0
    for swap_info: SwapInfo in swap_infos:
        last_index: uint256 = 0
        for i: uint256 in range(6):
            last_index = unsafe_sub(10, unsafe_add(i, i))
            if swap_info.route[last_index] != empty(address):
                break
        assert swap_info.route[last_index] == DAI
        assert swap_info.amount > 0, "Insuf deposit"
        out_amount: uint256 = 0
        if swap_info.route[0] == VETH:
            assert _value >= swap_info.amount, "Insuf deposit"
            _value = unsafe_sub(_value, swap_info.amount)
            out_amount = extcall CurveSwapRouter(ROUTER).exchange(swap_info.route, swap_info.swap_params, swap_info.amount, swap_info.expected, swap_info.pools, value=swap_info.amount)
        elif swap_info.route[0] == DAI:
            self._safe_transfer_from(DAI, msg.sender, self, swap_info.amount)
            out_amount = swap_info.amount
        else:
            self._safe_transfer_from(swap_info.route[0], msg.sender, self, swap_info.amount)
            self._safe_approve(swap_info.route[0], ROUTER, swap_info.amount)
            out_amount = extcall CurveSwapRouter(ROUTER).exchange(swap_info.route, swap_info.swap_params, swap_info.amount, swap_info.expected, swap_info.pools)
        dai_amount += out_amount
        log Deposited(_next_deposit, swap_info.route[0], swap_info.amount, out_amount, msg.sender, number_trades, interval)
        _next_deposit = unsafe_add(_next_deposit, 1)
    assert dai_amount > 0, "Insuf deposit"
    self._safe_approve(DAI, BRIDGE, dai_amount)
    extcall DaiBridge(BRIDGE).relayTokens(OPPOSITE, dai_amount)
    self.next_deposit = _next_deposit
    if _value > 0:
        send(msg.sender, _value)

@external
@payable
def __default__():
    pass
