# Scripts (API version 19.12):
## Modules: 
* dell.avamar.psm1 (API version 19.4)
    * PowerShell7 module that covers basic interaction with the PowerProtect Data Manager REST API
    * Functions
        * connect-restapi: method to request a bearer token
        * get-datadomains: method to query for attached dd systems
        * get-clients: method to perform a recursive query for clients
        * get-checkpoints: method to query for system checkpoints
        * get-systemevents: method to query for merged system events
    * Tasks
        * Task-01: example query for powerprotect dd systems
        * Task-02: example query for clients
        * Task-03: example query for valid and invalid system checkpoints
        * Task-04: example query for merged system events
