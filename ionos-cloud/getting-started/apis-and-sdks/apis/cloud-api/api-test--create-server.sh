#!/bin/bash
DATACENTER_UUID=""
API_ENDPOINT="https://api.ionos.com/cloudapi/v6/datacenters/${DATACENTER_UUID}/servers"
DATA=$(cat << EOF
{
	"properties": {
		"availabilityZone": "AUTO",
		"cores": 1,
		"cpuFamily": "INTEL_SKYLAKE",
		"name": "Example server",
		"ram": 1024,
		"type": "ENTERPRISE"
	},
	"entities": {
		"nics": {
			"items": [
				{
					"properties": {
						"dhcp": false,
						"firewallActive": false,
						"firewallType": "INGRESS",
						"ips": [],
						"lan": 1,
						"name": "eth0"
					}
				},
				{
					"properties": {
						"dhcp": true,
						"firewallActive": false,
						"firewallType": "INGRESS",
						"ips": [],
						"lan": 2,
						"name": "eth1"
					}
				}
			]
		}
	}
}
EOF
)


# create a server 
curl -X POST "${API_ENDPOINT}?pretty=true&depth=0" \
  -H "accept: application/json" \
  -H "Authorization: Bearer ${IONOS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${DATA}"


