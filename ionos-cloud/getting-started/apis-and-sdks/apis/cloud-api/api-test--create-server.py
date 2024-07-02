import sys
import os
import time
import requests
import json

try:
    IONOS_TOKEN = os.environ['IONOS_TOKEN']
except:
    print("Please ensure the IONOS_TOKEN environment variable is set and try again")
    sys.exit(1)


DATACENTER_UUID = ""
DATA = {
	"properties": {
		"availabilityZone": "AUTO",
		"cores": 1,
		"cpuFamily": "INTEL_SKYLAKE",
		"name": "Example server",
		"ram": 1024,
		"type": "ENTERPRISE"
	}
}
TIMEOUT_PERIOD = 600
INITIAL_WAIT = 2
TIMEOUT_SCALEUP = 10


# Setup our session
session = requests.Session()
session.headers = { 'Authorization': "Bearer %s" % IONOS_TOKEN }


res = session.post("https://api.ionos.com/cloudapi/v6/datacenters/%s/servers" % DATACENTER_UUID, json=DATA)
print(f"{res.headers['Date']}: POST {DATACENTER_UUID}/servers, Status: {res.status_code}")


# the incorrect way to check its status
# if res.status_code == 202:
#     SERVER_UUID = json.loads(res._content)['id']

#     for i in range(30):
#         res = session.get("https://api.ionos.com/cloudapi/v6/datacenters/%s/servers/%s" % (DATACENTER_UUID, SERVER_UUID))
#         print(f"{res.headers['Date']}: GET servers/{SERVER_UUID}, Status: {res.status_code}, {res.reason}")
#         time.sleep(2)



# the correct way to do so is to query / poll res.headers['Location'] --- see, e.g.,
# https://api.ionos.com/docs/cloud/v6/#tag/Requests/operation/requestsStatusGet,
# https://github.com/ionos-cloud/module-ansible/blob/master/plugins/modules/server.py#L542
# and https://github.com/ionos-cloud/sdk-python/blob/master/ionoscloud/api_client.py#L773
requestID = res.headers['Location']
timeout = time.time() + TIMEOUT_PERIOD
wait_period = INITIAL_WAIT
scaleup = TIMEOUT_SCALEUP
next_increase = time.time() + wait_period * scaleup
while True:
    res = session.get(requestID)
    status = json.loads(res._content)['metadata']['status']

    if status == 'DONE':
        print(f"Call for request {requestID} successfully completed")
        break

    elif status == 'FAILED':
        print(f"Call failed with error {json.loads(res._content)['metadata']['message']}")
        sys.exit(2)
    
    current_time = time.time()
    if current_time > timeout:
        print(f"Call for request {requestID} has timed out")
        sys.exit(3)

    if current_time > next_increase:
        wait_period *= 2
        next_increase = time.time() + wait_period * scaleup
        scaleup *= 2

    print(f"wait_period = {wait_period}, scaleup = {scaleup}, next_increase = {next_increase}")
    time.sleep(wait_period)

