#pragma version 0.3.10

interface CurveSwapRouter:
    def exchange(_route: address[11], _swap_params: uint256[5][5], _amount: uint256, _expected: uint256, _pools: address[5], _receiver: address) -> uint256: payable
    def get_dy(_route: address[11], _swap_params: uint256[5][5], _amount: uint256, _pools: address[5]) -> uint256: view

interface WxDAI:
    def deposit(): payable

interface ERC20:
    def approve(guy: address, wad: uint256): nonpayable

VETH: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE # Virtual ETH
WXDAI: constant(address) = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d
EURe: constant(address) = 0xcB444e90D8198415266c6a2724b7900fb12FC56E
ROUTER: constant(address) = 0xF0d4c12A5768D806021F80a262B4d39d26C58b8D
ROUTE: constant(address[11]) = [0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d, 0xE3FFF29d4DC930EBb787FeCd49Ee5963DADf60b6, 0xcB444e90D8198415266c6a2724b7900fb12FC56E, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000]
SWAP_PARAMS: constant(uint256[5][5]) = [[1, 0, 2, 2, 4], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0]]
POOLS: constant(address[5]) = [0x056C6C5e684CeC248635eD86033378Cc444459B0, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000]
MAX_SIZE: constant(uint256) = 8
DENOMINATOR: constant(uint256) = 10000
deposit_id_list: public(HashMap[uint256, bool])
compass_evm: public(address)
next_deposit: public(uint256)
paloma: public(bytes32)

event Swapped:
    receiver: address
    amount: uint256
    deposit_id: uint256

event UpdateCompass:
    old_compass: address
    new_compass: address

event SetPaloma:
    paloma: bytes32

@external
def __init__(_compass_evm: address):
    self.compass_evm = _compass_evm
    log UpdateCompass(empty(address), _compass_evm)

@external
def swap(receiver: address, amount: uint256, expected: uint256, deposit_id: uint256) -> uint256:
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 132, "Unauthorized"
    assert not self.deposit_id_list[deposit_id], "Already swapped"
    WxDAI(WXDAI).deposit(value=amount)
    ERC20(WXDAI).approve(ROUTER, amount)
    ret: uint256 = CurveSwapRouter(ROUTER).exchange(ROUTE, SWAP_PARAMS, amount, expected, POOLS, receiver)
    self.deposit_id_list[deposit_id] = True
    log Swapped(receiver, amount, deposit_id)
    return ret

@external
@view
def get_expected(amount: uint256) -> uint256:
    return CurveSwapRouter(ROUTER).get_dy(ROUTE, SWAP_PARAMS, amount, POOLS)

@external
def set_paloma():
    assert msg.sender == self.compass_evm and self.paloma == empty(bytes32) and len(msg.data) == 36, "Invalid"
    _paloma: bytes32 = convert(slice(msg.data, 4, 32), bytes32)
    self.paloma = _paloma
    log SetPaloma(_paloma)

@external
def update_compass(new_compass: address):
    assert msg.sender == self.compass_evm and len(msg.data) == 68 and convert(slice(msg.data, 36, 32), bytes32) == self.paloma, "Unauthorized"
    self.compass_evm = new_compass
    log UpdateCompass(msg.sender, new_compass)

@external
@payable
def __default__():
    pass
