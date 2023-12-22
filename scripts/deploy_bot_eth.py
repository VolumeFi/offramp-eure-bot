from ape import accounts, project, networks


def main():
    acct = accounts.load("deployer_account")
    dai = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    bridge = "0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016"
    router = "0xF0d4c12A5768D806021F80a262B4d39d26C58b8D"
    opposite = "0x48afa99CD4166D89718cbA46DB7e1eEb99535b46"

    max_priority_fee = int(networks.active_provider.priority_fee)
    max_base_fee = int(
        (networks.active_provider.base_fee + max_priority_fee) * 1.2)
    eth_bot = project.offramp_twapbot_eth.deploy(
        dai, bridge, router, opposite, max_fee=max_base_fee,
        max_priority_fee=max_priority_fee, sender=acct)
    print(eth_bot)
