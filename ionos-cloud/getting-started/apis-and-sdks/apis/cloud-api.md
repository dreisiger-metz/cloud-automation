# Getting Started with the Cloud API
> **Warning**
>
> The code-snippets included in this note are provided _without warranty_, as an examples of how to use specific aspects of the IONOS Cloud API / SDK.
>
> While every effort has been made to ensure that the information and/or code contained herein is current and works as intended, it has not been through any formal or rigorous testing process, and therefore should be used at your own discretion.
>
> For _definitive_ information and documentation, please refer to [docs.ionos.com/cloud](https://docs.ionos.com/cloud/)
>
> Additionally, some of the examples given below will result in resources being provisioned, and therefore ADDITIONAL COSTS (see [cloud.ionos.com/prices](https://cloud.ionos.com/prices), [cloud.ionos.de/preise](https://cloud.ionos.de/preise) or the appropriate page for your contract for pricing information). To avoid unwanted charges, please be sure to review the contents of your contract (e.g., via the [DCD](https://dcd.ionos.com)) and remove any resources that are no longer necessary and/or whose API-based clean-up might have failed.

Note to self: pull in relevant bits from https://otrs.fkb.profitbricks.net/otrs/index.pl?Action=AgentTicketZoom;TicketID=118368#529948, in particular, around the use of `IONOS_LOG_LEVEL=trace` with `ionosctl`.