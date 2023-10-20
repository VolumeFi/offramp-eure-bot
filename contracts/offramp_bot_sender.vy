#pragma version 0.3.10

"""
@title Offramp Bot Sender
@license Apache 2.0
@author Volume.finance
"""

struct SwapInfo:
    route: address[9]
    swap_params: uint256[3][4]
    amount: uint256
    expected: uint256
    pools: address[4]

interface WrappedEth:
    def deposit(): payable

interface CurveSwapRouter:
    def exchange_multiple(
        _route: address[9],
        _swap_params: uint256[3][4],
        _amount: uint256,
        _expected: uint256,
        _pools: address[4]=[ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS],
        _receiver: address=msg.sender
    ) -> uint256: payable

interface ERC20:
    def balanceOf(_owner: address) -> uint256: view

interface DaiBridge:
    def relayTokens(_receiver: address, _amount: uint256): nonpayable

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE # Virtual ETH
DAI: immutable(address)
BRIDGE: immutable(address)
ROUTER: immutable(address)
MAX_SIZE: constant(uint256) = 8
DENOMINATOR: constant(uint256) = 10000
compass_evm: public(address)
opposite: public(address)
next_deposit: public(uint256)
refund_wallet: public(address)
fee: public(uint256)
paloma: public(bytes32)
service_fee_collector: public(address)
service_fee: public(uint256)

event Deposited:
    deposit_id: uint256
    input_amount: uint256
    depositor: address

event UpdateCompass:
    old_compass: address
    new_compass: address

event UpdateRefundWallet:
    old_refund_wallet: address
    new_refund_wallet: address

event UpdateFee:
    old_fee: uint256
    new_fee: uint256

event SetPaloma:
    paloma: bytes32

event UpdateOpposite:
    old_opposite: address
    new_opposite: address

event UpdateServiceFeeCollector:
    old_service_fee_collector: address
    new_service_fee_collector: address

event UpdateServiceFee:
    old_service_fee: uint256
    new_service_fee: uint256

@external
def __init__(_compass_evm: address, dai: address, bridge: address, router: address, _refund_wallet: address, _fee: uint256, _service_fee_collector: address, _service_fee: uint256):
    self.compass_evm = _compass_evm
    ROUTER = router
    DAI = dai
    BRIDGE = bridge
    self.refund_wallet = _refund_wallet
    self.fee = _fee
    self.service_fee_collector = _service_fee_collector
    assert _service_fee < DENOMINATOR
    self.service_fee = _service_fee
    log UpdateCompass(empty(address), _compass_evm)
    log UpdateRefundWallet(empty(address), _refund_wallet)
    log UpdateFee(0, _fee)
    log UpdateServiceFeeCollector(empty(address), _service_fee_collector)
    log UpdateServiceFee(0, _service_fee)

@internal
def _safe_approve(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        _abi_encode(_to, _value, method_id=method_id("approve(address,uint256)")),
        max_outsize=32
    )  # dev: failed approve
    if len(_response) > 0:
        assert convert(_response, bool), "failed approve"  # dev: failed approve

@internal
def _safe_transfer(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        _abi_encode(_to, _value, method_id=method_id("transfer(address,uint256)")),
        max_outsize=32
    )  # dev: failed transfer
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed transfer

@internal
def _safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        _abi_encode(_from, _to, _value, method_id=method_id("transferFrom(address,address,uint256)")),
        max_outsize=32
    )  # dev: failed transferFrom
    if len(_response) > 0:
        assert convert(_response, bool), "failed transferFrom"  # dev: failed transferFrom

@external
@payable
@nonreentrant('lock')
def deposit(swap_infos: DynArray[SwapInfo, MAX_SIZE]):
    _value: uint256 = msg.value
    assert self.paloma != empty(bytes32), "Paloma not set"
    _opposite: address = self.opposite
    assert _opposite != empty(address), "Opposite not set"
    _fee: uint256 = self.fee
    if _fee > 0:
        assert _value >= _fee, "Insufficient fee"
        send(self.refund_wallet, _fee)
        _value = unsafe_sub(_value, _fee)
    _next_deposit: uint256 = self.next_deposit
    dai_amount: uint256 = 0
    for swap_info in swap_infos:
        last_index: uint256 = 0
        for i in range(4):
            last_index = 8 - i * 2
            if swap_info.route[last_index] != empty(address):
                break
        assert swap_info.route[last_index] == DAI
        assert swap_info.amount > 0, "Insufficient deposit"
        out_amount: uint256 = 0
        if swap_info.route[0] == VETH:
            assert _value >= swap_info.amount, "Insufficient deposit"
            _value = unsafe_sub(_value, swap_info.amount)
            out_amount = CurveSwapRouter(ROUTER).exchange_multiple(swap_info.route, swap_info.swap_params, swap_info.amount, swap_info.expected, swap_info.pools, self, value=swap_info.amount)
        elif swap_info.route[0] == DAI:
            self._safe_transfer_from(DAI, msg.sender, self, swap_info.amount)
            out_amount = swap_info.amount
        else:
            self._safe_transfer_from(swap_info.route[0], msg.sender, self, swap_info.amount)
            self._safe_approve(swap_info.route[0], ROUTER, swap_info.amount)
            out_amount = CurveSwapRouter(ROUTER).exchange_multiple(swap_info.route, swap_info.swap_params, swap_info.amount, swap_info.expected, swap_info.pools, self)
        dai_amount += out_amount
    service_fee: uint256 = self.service_fee
    service_fee_amount: uint256 = 0
    if service_fee > 0:
        service_fee_amount = unsafe_div(dai_amount * service_fee, DENOMINATOR)
        if service_fee_amount > 0:
            self._safe_transfer(DAI, self.service_fee_collector, service_fee_amount)
            dai_amount = unsafe_sub(dai_amount, service_fee_amount)
    self._safe_approve(DAI, BRIDGE, dai_amount)
    DaiBridge(BRIDGE).relayTokens(_opposite, dai_amount)
    log Deposited(_next_deposit, dai_amount, msg.sender)
    _next_deposit = unsafe_add(_next_deposit, 1)
    self.next_deposit = _next_deposit
    if _value > 0:
        send(msg.sender, _value)

@external
def update_compass(new_compass: address):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    self.compass_evm = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
def update_refund_wallet(new_refund_wallet: address):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet, new_refund_wallet)

@external
def update_fee(new_fee: uint256):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    old_fee: uint256 = self.fee
    self.fee = new_fee
    log UpdateFee(old_fee, new_fee)

@external
def set_paloma():
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 36, "Invalid"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
def set_opposite(new_opposite: address):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    old_opposite: address = self.opposite
    self.opposite = new_opposite
    log UpdateOpposite(old_opposite, new_opposite)

@external
def update_service_fee_collector(new_service_fee_collector: address):
    assert msg.sender == self.service_fee_collector, "Unauthorized"
    self.service_fee_collector = new_service_fee_collector
    log UpdateServiceFeeCollector(msg.sender, new_service_fee_collector)

@external
def update_service_fee(new_service_fee: uint256):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    assert new_service_fee < DENOMINATOR, "Wrong service fee"
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass
