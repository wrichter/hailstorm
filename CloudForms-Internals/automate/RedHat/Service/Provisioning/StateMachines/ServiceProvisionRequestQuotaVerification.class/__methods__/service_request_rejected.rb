#
# Description: This method runs when the service provision is denied because the quota limits were exceeded.
#

$evm.root["miq_request"].deny("admin", "Quota Exceeded")
