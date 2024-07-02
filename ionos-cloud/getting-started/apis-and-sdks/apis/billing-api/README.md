# Getting Started with the Billing API
From [api.ionos.com/docs/billing](https://api.ionos.com/docs/billing/), the IONOS Cloud Billing API "is a REST API that can be used to retrieve information about resource usage and invoices. Please note that only Contract Holders can log in and retrieve data. Information on usage is provided without liability."

While approximate / projected costs and usage for the most common types of resources can be seen in the DCD under 'Contract --> Cost and Usage', the Billing API can be used to retrieve 'actual' / metered usages for _all_ products; it can also be used to retrieve the historical data used to generate invoices.



## An Initial Example
While [api.ionos.com/docs/billing](https://api.ionos.com/docs/billing/) and its corresponding [OpenAPI specification](https://api.ionos.com/docs/public-billing-v3.ga.json) constitute the definitive documentation of the Billing API, an example of how one might use this (and the Cloud) API to calculate the expected costs for one's S3 usage is given below.

Note that unlike the other APIs (which support both Basic and Bearer / Token authentication), currently, the Billing API only supports 'Basic Authentication', hence the following examples' need for your password (although this could be imported from the `IONOS_PASSWORD` environment variable, or elsewhere).



### From the Shell
To estimate these costs, save the following snippet into a `.sh` file, e.g., `billing-api-example.sh`, change the variable definitions as necessary, and execute it as you would any other shell script. Please note that this example makes use of Curl, jq and Perl, and assumes they've already been installed.


```bash
#!/bin/bash
IONOS_AUTH_STRING="username@domain.tld:password"
QUERY_PERIOD="2022-12"

CONTRACT_NUMBER=$(curl -s -u ${IONOS_AUTH_STRING} "https://api.ionos.com/cloudapi/v6/contracts" | jq -r ".items[0].properties.contractNumber")
for meter in $(curl -s -u ${IONOS_AUTH_STRING} "https://api.ionos.com/billing/${CONTRACT_NUMBER}/products/" | jq -r ".products[] | .meterId" | grep "^S3SU")
do
  cost=$(curl -s -u ${IONOS_AUTH_STRING} "https://api.ionos.com/billing/${CONTRACT_NUMBER}/products/" | jq -r ".products[] | select(.meterId == \"$meter\") | .unitCost.quantity")
  echo Meter = $meter has cost = $cost
  total=0
  for util in $(curl -s -u ${IONOS_AUTH_STRING} "https://api.ionos.com/billing/${CONTRACT_NUMBER}/utilization/${QUERY_PERIOD}?type=S3" | jq -r ".datacenters[].meters[] | select(.meterId == \"$meter\") | .quantity.quantity")
  do
    summing=$(perl -e "print $total + $util * $cost / 30")
    total=$summing
  done
  echo Total costs = $total EUR
  echo .
done
```



### Using Python 3
The following code-snippet shows how you can calculate this information in Python 3; to execute it, either save it into a `.py` file, e.g., `billing-api-example.py`, change the variable definitions as necessary, and execute it using the command `python3 billing-api-example.py`. (See [here](README.md#using-python-3) for an example of how you might retrieve the credentials from their corresponding environment variables.)


```python
import requests
import json

# Change these to match your credentials and the desired query period
IONOS_USERNAME = "username@domain.tld"
IONOS_PASSWORD = "password"
QUERY_PERIOD   = "2022-12"

# Setup our session
session = requests.Session()
session.auth = (IONOS_USERNAME, IONOS_PASSWORD)


# Authenticate against the Cloud API to retrieve our Contract Number
auth = session.post('https://api.ionos.com/cloudapi/v6')
CONTRACT_NUMBER = str((session.get('https://api.ionos.com/cloudapi/v6/contracts').json())['items'][0]['properties']['contractNumber'])


# And authenticate against the Billing API to get the rest of the data
auth = session.post('https://api.ionos.com/billing')
response = session.get(f"https://api.ionos.com/billing/{CONTRACT_NUMBER}/products/").json()
currency = response['products'][0]['unitCost']['unit']
s3unitCosts = { p['meterId']: float(p['unitCost']['quantity']) for p in response['products'] if p['meterId'][:4] in [ "S3SU", "S3TI", "S3TO", "CTO1" ] }
s3unitCosts['S3TO1000'] = s3unitCosts['CTO1100']    # a slight fudge to provide an estimate of the network-traffic-related charges

response = session.get(f"https://api.ionos.com/billing/{CONTRACT_NUMBER}/utilization/{QUERY_PERIOD}?type=S3").json()
meters = [ i for i in response['datacenters'][0]['meters'] if i['meterId'][0:4] in [ "S3SU", "S3TI", "S3TO" ] ]
totalUsage = sum([ m['quantity']['quantity'] for m in meters if m['meterId'][0:4] == "S3SU" ])
totalCosts = sum([ m['quantity']['quantity'] * s3unitCosts[m['meterId']] for m in meters ])

print(f"Total S3SU* usage for Contract {CONTRACT_NUMBER} for the period {QUERY_PERIOD}: {totalUsage} GB*Months")
print(f"Total S3SU* costs for Contract {CONTRACT_NUMBER} for the period {QUERY_PERIOD}: {currency} {round(totalCosts, 3)}")
```



## Exploring the Billing API
In addition to the human-readable documentation over at [api.ionos.com/docs/billing](https://api.ionos.com/docs/billing/), you can use the corresponding [OpenAPI specification](https://api.ionos.com/docs/public-billing-v3.ga.json) and a tool like [Postman](https://postman.com) or [Swagger](https://swagger.io) to try out API calls interactively, and to see Curl command line examples.

See [Getting Started with the IONOS Cloud APIs / Exploring the APIs more Interactively](README.md#exploring-the-apis-more-interactively) for more information.