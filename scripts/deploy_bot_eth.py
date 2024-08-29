from ape import accounts, project, networks


def main():
    acct = accounts.load("deployer_account")
    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    bridge = "0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016"
    router = "0x16C6521Dff6baB339122a0FE25a9116693265353"
    opposite = "0xE105DA50a007246255cf91B42a82dd9FF5971243"

    max_priority_fee = int(networks.active_provider.priority_fee)
    max_base_fee = int(
        (networks.active_provider.base_fee + max_priority_fee) * 1.2)
    eth_bot = project.offramp_bot_eth.deploy(
        dai, bridge, router, opposite, max_fee=max_base_fee,
        max_priority_fee=max_priority_fee, sender=acct)
    print(eth_bot)
