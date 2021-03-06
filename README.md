# iCDM4XtremIO
iCDM4XtremIO is a repository that stores sample scripts/modules that demostrate automation for iCDM use-case

## Description

### Problem statement
Critical business processes require multiple copies of each database and application’s
data for purposes such as development, analytics, operations and data protection. To
improve organizational agility and competitiveness, more is better—more copies,
more frequently, with more operational self-service across the process cycles.
Organizations have relied on brute force copies with storage tiering, flawed snapshots,
and dedicated copy management tools, for managing the creation and maintenance of
copies. IDC and Gartner call this product category “Copy Data Management”, or CDM.

### Drawbacks of traditional "Copy Data Management"
All current CDM approaches struggle fundamentally with storage sprawl,
performance/scalability and SLA issues, limitations on copy frequency and complex
operational processes. Today’s Limited CDM methodologies result in expensive, slow and complex copy
management operations, which do not meet the needs of business. Therefore,
application/DBA teams are faced with the following challenges:
 - Bloated copies
 - Insufficient copies
 - Handicapped copies
 - Painful copy creation & management
 - Stale copies
 - Compromised business process workflows

### integrated Copy Data Management [iCDM]
XtremIO pioneered the concept of integrated copy data management (iCDM) –
the ability to consolidate both primary data and its associated copies on the same scale-out all-flash array for unprecedented agility and efficiency. With its bullet-proof, consistent IOPS and latency, linear scale-out all-flash performance and the ability to add more performance and capacity as needed with no application downtime, XtremIO delivers incredible potential to finally consolidate production AND non-production applications, without impacting the production SLAs.

iCDM4XtremIO is a repository that contains samples written in Powershell that 
- Demonstrates how we can leverage iCDM capabilities of XtremIO in re-purposing databases
- How we can automate workflows combining different PowerCLI modules and leveraging their capabilities
- How we can wrap XtremIO REST API invocation in custom powershell scripts that are tailored to our needs

Currently, there is collection of scripts that demonstrate how we can leverage iCDM to create an instant crash consistent copy of a Microsoft SQL Database and re-purpose it to a virtual machine emulating Dev/Test environment. The module,
- Provisions a new copy (if needed) of SQL database to a Dev/Test environment by creating a brand new XVC (XtremIO virtual copy)
- Refresh a pre-existing copy of SQL database by refreshing a pre-existing XVC with recent changes in the parent volume

## Installation
The existing sample has dependency on following two modules
- VMware vSphere PowerCLI
- Microsoft SQLPS module
Users should make sure that they install vSphere PowerCLI snapin and sqlps module before using this script

## Usage Instructions
#### iCDM-DevOps
- Download the powershell module db_repurpose.ps1 to the VM where you have vSphere PowerCLI and sqlps installed
- Download and save createDB.ps1 to C:\ of the virtual machine where a copy of the database will be re-purposed
- Download and save createTpceDatabase.sql to C:\ of the virtual machine where a copy of the database will be re-purposed
- Open powershell console, change the directory to where you have copied db_repurpose.ps1
- .execute /db_repurpose.ps1 -DBVmName <name of the VM where a copy of the database is to be re-purposed>

## Future
In future, we may have more samples may be added that demonstrate examples of 
- iCDM enabling oracle database.
- iCDM enabling SQL database with mandatory data masking
- iCDM enabling application consistent snapshots

We will update this readme with appropriate usage instructions for the respective modules

## Contribution
Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.

Create a sub-folder pre-fixed with iCDM- and the use-case that underlying scripts/modules/libraries are meant to target.

Licensing
---------
iCDM4XtremIO is freely distributed under the [MIT License](http://emccode.github.io/sampledocs/LICENSE "LICENSE"). See LICENSE for details.


Support
-------
Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo. For general discussions and further support you can join the [EMC {code} Community slack channel](http://community.emccode.com/). Lastly, for questions asked on [Stackoverflow.com](https://stackoverflow.com) please tag them with **EMC**. The code and documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.
