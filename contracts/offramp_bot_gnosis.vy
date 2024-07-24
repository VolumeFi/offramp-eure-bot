#pragma version 0.3.10
#pragma optimize gas
#pragma evm-version shanghai
"""
@title Offramp TWAP Bot on Gnosis
@license Apache 2.0
@author Volume.finance
"""
interface CurveSwapRouter:
    def exchange(_route: address[11], _swap_params: uint256[5][5], _amount: uint256, _expected: uint256, _pools: address[5], _receiver: address) -> uint256: payable
    def get_dy(_route: address[11], _swap_params: uint256[5][5], _amount: uint256, _pools: address[5]) -> uint256: view

interface WxDAI:
    def deposit(): payable

interface ERC20:
    def approve(guy: address, wad: uint256): nonpayable

WXDAI: constant(address) = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d
ROUTER: constant(address) = 0xF0d4c12A5768D806021F80a262B4d39d26C58b8D
ROUTE: constant(address[11]) = [0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d, 0xE3FFF29d4DC930EBb787FeCd49Ee5963DADf60b6, 0xcB444e90D8198415266c6a2724b7900fb12FC56E, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000]
SWAP_PARAMS: constant(uint256[5][5]) = [[1, 0, 2, 2, 4], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
POOLS: constant(address[5]) = [0x056C6C5e684CeC248635eD86033378Cc444459B0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000]
DENOMINATOR: constant(uint256) = 10 ** 18
number_trades: public(HashMap[uint256, uint256])
remaining_counts: public(HashMap[uint256, uint256])
compass_evm: public(address)
refund_wallet: public(address)
fee: public(uint256)
paloma: public(bytes32)
service_fee_collector: public(address)
service_fee: public(uint256)

event Swapped:
    receiver: address
    amount: uint256
    deposit_id: uint256
    number_trades: uint256

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
def __init__(_compass_evm: address, _refund_wallet: address, _fee: uint256, _service_fee_collector: address, _service_fee: uint256):
    self.compass_evm = _compass_evm
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
def _paloma_check():
    assert msg.sender == self.compass_evm, "Not compass"
    assert self.paloma == convert(slice(msg.data, unsafe_sub(len(msg.data), 32), 32), bytes32), "Invalid paloma"

@external
@nonreentrant('lock')
def swap(receiver: address, amount: uint256, expected: uint256, deposit_id: uint256, number_trades: uint256) -> uint256:
    self._paloma_check()
    assert number_trades > 0, "Wrong count"
    if self.number_trades[deposit_id] == 0:
        self.number_trades[deposit_id] = number_trades
        self.remaining_counts[deposit_id] = unsafe_sub(number_trades, 1)
    else:
        assert self.remaining_counts[deposit_id] == number_trades, "Wrong count"
        self.remaining_counts[deposit_id] = unsafe_sub(number_trades, 1)
    _fee: uint256 = self.fee
    if amount <= _fee:
        send(self.refund_wallet, amount)
        log Swapped(receiver, 0, deposit_id, number_trades)
        return 0
    else:
        send(self.refund_wallet, _fee)
        _amount: uint256 = unsafe_sub(amount, _fee)
        service_fee: uint256 = self.service_fee
        service_fee_amount: uint256 = 0
        if service_fee > 0:
            service_fee_amount = unsafe_div(_amount * service_fee, DENOMINATOR)
            if service_fee_amount > 0:
                send(self.service_fee_collector, service_fee_amount)
                _amount = unsafe_sub(_amount, service_fee_amount)
        WxDAI(WXDAI).deposit(value=_amount)
        ERC20(WXDAI).approve(ROUTER, _amount)
        ret: uint256 = CurveSwapRouter(ROUTER).exchange(ROUTE, SWAP_PARAMS, _amount, expected, POOLS, receiver)
        log Swapped(receiver, _amount, deposit_id, number_trades)
        return ret

@external
@view
def get_expected(amount: uint256) -> uint256:
    _fee: uint256 = self.fee
    if amount <= _fee:
        return 0
    else:
        return CurveSwapRouter(ROUTER).get_dy(ROUTE, SWAP_PARAMS, unsafe_sub(amount, _fee), POOLS)

@external
def update_compass(new_compass: address):
    self._paloma_check()
    self.compass_evm = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
def update_refund_wallet(new_refund_wallet: address):
    self._paloma_check()
    old_refund_wallet: address = self.refund_wallet
    self.refund_wallet = new_refund_wallet
    log UpdateRefundWallet(old_refund_wallet, new_refund_wallet)

@external
def update_fee(new_fee: uint256):
    self._paloma_check()
    old_fee: uint256 = self.fee
    self.fee = new_fee
    log UpdateFee(old_fee, new_fee)

@external
def set_paloma():
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 36, "Unauthorized"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
def update_service_fee_collector(new_service_fee_collector: address):
    self._paloma_check()
    self.service_fee_collector = new_service_fee_collector
    log UpdateServiceFeeCollector(msg.sender, new_service_fee_collector)

@external
def update_service_fee(new_service_fee: uint256):
    self._paloma_check()
    assert new_service_fee < DENOMINATOR, "Wrong service fee"
    old_service_fee: uint256 = self.service_fee
    self.service_fee = new_service_fee
    log UpdateServiceFee(old_service_fee, new_service_fee)

@external
@payable
def __default__():
    pass
