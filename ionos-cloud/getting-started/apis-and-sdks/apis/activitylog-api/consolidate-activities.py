# This code-snippet is provided without warranty, as an example of, not only
# how to query https://api.ionos.com/docs/activitylog/v1), but how to 'join'
# or 'consolidate' the 'who did something', 'when did they do it' and 'to
# which resource(s)' answered by the ActivityLog, with the 'what was actually
# done' that is answered by https://api.ionos.com/cloudapi/v6/requests/.
# 
# While every effort has been made to ensure that the information and/or code
# contained herein is current and works as intended, it has not been through 
# any formal or rigorous testing process, and therefore should be used at your
# own discretion. For definitive information and documentation, please refer
# to docs.ionos.com/cloud and/or https://api.ionos.com/docs/cloud
#
# Author: Peter Metz
import requests
import json
import os
import sys




# Get the user's API token
try:
    IONOS_TOKEN = os.environ['IONOS_TOKEN']
except:
    print("Please ensure the IONOS_TOKEN environment variable is set and try again")
    sys.exit(1)


# Specify the query interval and optionally, (in the case of resellers) the
# sub-contract number
QUERY_START     = "2024-02-20"    # or, e.g., "2024-02-12T00:00:00Z"
QUERY_END       = "2024-02-21"    # or, e.g., "2024-02-12T23:59:59Z"
CONTRACT_NUMBER = ""




# Setup our session
session = requests.Session()
session.headers = { 'Authorization': "Bearer %s" % IONOS_TOKEN }


# If CONTRACT_NUMBER is not specified, set it to the first Contract Number
# returned by https://api.ionos.com/docs/activitylog/v1/#tag/Contracts; if it
# was specified, then set the X-Contract-Number header parameter accordingly
if CONTRACT_NUMBER == "":
  CONTRACT_NUMBER = str((session.get('https://api.ionos.com/activitylog/v1/contracts').json())[0]['id'])
else:
   session.headers['X-Contract-Number'] = CONTRACT_NUMBER


# Retrieve (up to) the first 100 activities for the specified contract and 
# interval --- if you wish to retrieve more, you will need to 'paginate' your
# query and submit it over multiple GETs...
res = session.get(f"https://api.ionos.com/activitylog/v1/contracts/{CONTRACT_NUMBER}"\
                  f"?dateStart={QUERY_START}&dateEnd={QUERY_END}&offset=0&limit=100")
if res.status_code == 200:
  activities = json.loads(res._content)['hits']['hits']

  # Now that we have a list of 'activities', we will iterate through it, and
  # for those requests with a source beginning with 'PUBLIC_REST' and whose
  # action is something _other_ than 'GET', we will retrieve the details of
  # the corresponding request via the _CloudAPI_... See
  # https://api.ionos.com/docs/cloud/v6/#tag/Requests/operation/requestsFindById
  # for more information
  for activity in activities:
    event_param = activity['_source']['event']['param']
    if activity['_source']['principal']['sourceService'].startswith('PUBLIC_REST') and 'action' in event_param and event_param != 'GET':
      res = session.get(f"https://api.ionos.com/cloudapi/v6/requests/{activity['_source']['meta']['requestId']}")
      if res.status_code == 200:
        activity['_source']['meta']['imported_from_cloudapi'] = { 'status_code': res.status_code, '_content': json.loads(res._content)}


# Sample function that selects only those activities for which a corresponding
# request could be retrieved via the CloudAPI, and (by default) also prints out
# their JSON representation
def activitiesWithRequests(activities, printActivities = True):
  filtered_activities = [ a for a in activities if 'imported_from_cloudapi' in a['_source']['meta'] ]
  if printActivities:
    print(json.dumps(filtered_activities, indent = 2))

  return filtered_activities
