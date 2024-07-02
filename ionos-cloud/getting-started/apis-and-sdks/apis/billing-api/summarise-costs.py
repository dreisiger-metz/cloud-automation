# This code-snippet is provided without warranty, as an example of how to per-
# form certain maintenance tasks or operations.
# 
# While every effort has been made to ensure that the information and/or code
# contained herein is current and works as intended, it has not been through 
# any formal or rigorous testing process, and therefore should be used at your
# own discretion. For definitive information and documentation, please refer
# to docs.ionos.com/cloud
#
# Author: Peter Metz
import requests
import json
import os
import getpass


# Get the user's API token
try:
    IONOS_TOKEN = os.environ['IONOS_TOKEN']
except:
    print("Please ensure the IONOS_TOKEN environment variable is set and try again")
    sys.exit(1)



# Specify the query period and meters of interest; set the latter to an empty
# list to retrieve all meters
# METERS_TO_QUERY = [ "TI1000", "TO1100", "TO1200", "TO1300", "TO1400" ]
QUERY_PERIOD   = "2023-03"
METERS_TO_QUERY = [ ]

# For reseller master users, set CONTRACT_NUMBER to the child contract in
# question; otherwise leave it empty and the contract number corresponding
# to IONOS_USERNAME will be retrieved via the CloudAPI
CONTRACT_NUMBER = ""



# Setup our session
session = requests.Session()
session.headers = { 'Authorization': "Bearer %s" % IONOS_TOKEN }



# Authenticate against the Cloud API to retrieve our Contract Number
auth = session.post('https://api.ionos.com/cloudapi/v6')
if CONTRACT_NUMBER == "":
  CONTRACT_NUMBER = str((session.get('https://api.ionos.com/cloudapi/v6/contracts').json())['items'][0]['properties']['contractNumber'])


# And authenticate against the Billing API to get the rest of the data
auth = session.post('https://api.ionos.com/billing')
response = session.get(f"https://api.ionos.com/billing/{CONTRACT_NUMBER}/products/").json()
currency = response['products'][0]['unitCost']['unit']
units = { p['meterId']: { 'unitCost': float(p['unitCost']['quantity']), 'meterDesc': p['meterDesc'] } for p in response['products'] }


response = session.get(f"https://api.ionos.com/billing/{CONTRACT_NUMBER}/utilization/{QUERY_PERIOD}").json()
summary = { '_metadata': { 'metersWithoutUnitCostEntries': set() } }

for vdc in response['datacenters']:
  # extract the meters of interest for this specific VDC, and initialise `costs` accordingly, too
  if len(METERS_TO_QUERY) > 0:
    meters = [ i for i in vdc['meters'] if i['meterId'] in METERS_TO_QUERY ]
  else:
    meters = [ i for i in vdc['meters'] ]

  costs = { m['meterId']: 0 for m in meters }

  # aggregate costs at the meter-level
  for m in meters:
    if m['meterId'] in units:
      costs[m['meterId']] += m['quantity']['quantity'] * units[m['meterId']]['unitCost']
    else:
      summary['_metadata']['metersWithoutUnitCostEntries'].add(m['meterId'])

  # and add this to `summary`, along with the VDC's ID and name
  summary[vdc['id']] = { 'id': vdc['id'], 'name': vdc['name'], 'costs': costs }


summary['_metadata']['units'] = units
summary['_metadata']['metersWithoutUnitCostEntries'] = list(set(summary['_metadata']['metersWithoutUnitCostEntries']))
print(f"{json.dumps(summary, indent=2)}")
