from ape import accounts, project, networks


def main():
    acct = accounts.load("deployer_account")
    compass = "0x2E00587b846ec97b293F86b1243Dd4280aA22CbF"
    refund_wallet = "0x6dc0A87638CD75Cc700cCdB226c7ab6C054bc70b"
    gas_fee = 15_000_000_000_000_000
    service_fee_collector = "0x7a16fF8270133F063aAb6C9977183D9e72835428"
    service_fee = 0
    max_base_fee = int(networks.active_provider.base_fee * 1.05)
    max_priority_fee = max(int(networks.active_provider.priority_fee), 1e9)
    gnosis_bot = project.offramp_bot_gnosis.deploy(
        compass, refund_wallet, gas_fee, service_fee_collector, service_fee,
        max_fee=max_base_fee, max_priority_fee=max_priority_fee, sender=acct)
    print(gnosis_bot)
