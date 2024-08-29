from ape import accounts, project, networks


def main():
    acct = accounts.load("deployer_account")
    compass = "0xEf2e3E09bCb5d1647D40E811D0396629549d16Ab"
    refund_wallet = "0x6dc0A87638CD75Cc700cCdB226c7ab6C054bc70b"
    gas_fee = 0
    service_fee_collector = "0xe693603C9441f0e645Af6A5898b76a60dbf757F4"
    service_fee = 2_000_000_000_000_000

    max_priority_fee = int(networks.active_provider.priority_fee)
    max_base_fee = int(
        (networks.active_provider.base_fee + max_priority_fee) * 1.2)
    gnosis_bot = project.offramp_bot_gnosis.deploy(
        compass, refund_wallet, gas_fee, service_fee_collector, service_fee,
        max_fee=max_base_fee, max_priority_fee=max_priority_fee, sender=acct)
    print(gnosis_bot)
