# AzOps

[![Build Status](https://dev.azure.com/mscet/CET-AzOps/_apis/build/status/Organizations/Azure/AzOps?branchName=main)](https://dev.azure.com/mscet/CET-AzOps)
![GitHub issues by-label](https://img.shields.io/github/issues/azure/azops/feature%20:bulb:?label=feature%20issues)
![GitHub issues by-label](https://img.shields.io/github/issues/azure/azops/bug%20:ambulance:?label=bug%20issues)
![GitHub issues by-label](https://img.shields.io/github/issues/azure/azops/enhancement%20:rocket:?label=enhancement%20issues)

## Welcome

This repository is home to the GitHub Action: AzOps.

## Design Objectives

This GitHub Action is rooted in the principle that **Everything in Azure is a resource** and to operate at-scale, it should be managed declaratively to **determine target goal state** of the overall platform.

In that spirit, this reference implementation has following three tenets:

![](./docs/media/implementation-scope.png)

### 1. Git -> clone -> Azure/Enterprise-Scale

Provide Git repository for Azure platform configuration.

Git -> Clone or Git -> Fork (preferred) metaphor references to the fact that this repo will provide everything that must be true for Enterprise-Scale - that customers can leverage as-is in their own environment.

#### Discovery

Before starting Enterprise-Scale journey, it is important for customers to discover existing configuration in Azure that can serve as platform baseline. Consequence of not discovering existing environment will be no reference point to rollback or roll-forward after deployment.
Discovery is also important for organizations, who are starting their DevOps and Infrastructure-as-code (IaC) journey, as this can provide crucial on-ramp path to allow transitioning without starting all-over.

For the purpose of discovery, following resources are considered within the scope of overall Azure platform. This will initialize empty Git repo with current configuration to baseline configuration encompassing following:

- Management Group hierarchy and Subscription organization
  - ResourceTypes:
    - Microsoft.Management/managementGroups
    - Microsoft.Management/managementGroups/subscriptions
    - Microsoft.Subscription/subscriptions
- Policy Definition and Policy Assignment for Governance
  - ResourceTypes:
    - Microsoft.Authorization/policyDefinitions
    - Microsoft.Authorization/policySetDefinitions
    - Microsoft.Authorization/policyAssignments
- Role Definition and Role Assignment
  - ResourceTypes:
    - Microsoft.Authorization/roleDefinitions
    - Microsoft.Authorization/roleAssignments

We will default to platform schema to represent these configuration in Git. This means calling Azure APIs using PowerShell.

#### Deployment

IaC repo will have 100s if not 1000s of configuration artefact tracked and version controlled. Platform developers will be modifying very small subset of these artefact on on-going basis via pull request. As Git represents source of the truth and change, we will leverage Git to determine differential changes in each pull request and trigger subsequent deployment action in Azure only for artefact those are changed instead of triggering full deployment of all.

#### Definition of Done (DoD)

- Discover current Azure environment "as-is" and have entire Azure platform baseline stored inside Git repo.
- Deploy  templates to Azure environment using pipeline by committing templates at appropriate scope without providing deployment scripts.
- Perform platform operations required for Enterprise-Scale but not yet supported inside ARM e.g. Resource Provider Registration, Azure AD Graph Operations etc. These operations should be handled via pipeline in the interim.

### 2. ARM as orchestrator to declare goal state

Provide tenant level ARM template to build Landing Zone using Enterprise-Scale guidelines.

We will enable security, logging, networking, and any other plumbing needed for landing zones (i.e. Subscription) **autonomously** by the way of policy enforcement. We will bootstrap Azure environment with ARM template to create necessary structure for management and networking to declare desired goal state.

File -> New -> Landing Zones (i.e. Subscription) process is ARM orchestrating following:

- Subscription creation
- Subscription move under the target management structure
- Configuring Subscription to desired state by policy enfrorcement - autonomously.

For quick start, an [**ARM template**](https://ms.portal.azure.com/?feature.customportal=false#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzOps%2Fmain%2Ftemplate%2Fux-foundation.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2FAzOps%2Fmain%2Ftemplate%2Fesux.json) that can be deployed at the tenant ("/") root scope will be provided to instantiate the **Enterprise-Scale architecture**. This template should provide everything that is necessary in [Implementation Guide](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/implementation-guidelines), and will have the following sequence:

- Create (1) Management Group hierarchy and (2) Subscription organization structure in (Platform + N) fashion where N represents number of landing zones.
- Create Policies (deployIfNotExists) assigned to (2) Management Groups and (3) Subscription scope to govern and deploy necessary resources, enabling platform autonomy as new landing zones (Subscriptions) are being created by application teams
- Create (3) Policy and Role Assignment to govern and delegate access to resources.

It is important to note that one of the design principle of the Enterprise-Scale is "Policy Driven Governance" and all the necessary resources leading to the creation of Landing Zone are deployed using policy. For example, Deploying Key Vault to store platform level secret in management Subscription. Instead of scripting the template deployment to deploy Key Vault, Enterprise-Scale based reference implementation will have a policy definition that deploy the Key Vault in prescribed manner and policy assignment at management Subscription scope. Benefit of the policy driven approach are manyfold but the most significant are:

- Platform can provide orchestration capability to bring target resources (in this case Subscription) to desired goal state.
- Continuous conformance to ensure all platform level resources are compliant. As platform is aware of the goal state, platform can assist by monitoring and remediating the resources throughout the life cycle of the resource.
- Platform enables autonomy regardless of the customer's scale point.

#### Definition of Done (DoD)

- Invoke ARM Template using PowerShell/CLI for tenant level deployment to create Landing Zone in Azure environment.
- End to end ARM template must allow flexibility to create requisite Management Group and Subscription hierarchy to organize Landing Zones.
- Template must allow declaring goal state at Tenant, Management Group and Subscriptions scope using policies.
- "Export" Azure configuration in a manner that can be consumed and "imported" back into platform.

### 3. "Operationalize" Azure environment at scale for day-to-day activities

In production environment, changes are bound to happen. Ideally these changes are made in a structured way, using the principles of Infrastructure-as-code (IaC): A change would be made by adding or updating a resource definition in an Azure DevOps or Github repository and relying on an automated test and release process to effectuate the change. This gives the IT department a fully transparent change history and full roll-back and roll-forward capabilities.

However, manual changes (made for example using the Azure portal) may be unavoidable due to urgent operational demands. This leads to 'Configuration Drift', where the environment as described in source control no longer reflects the actual state of the Azure resources. To deal with this situation, Enterprise-Scale envisions not only a control mechanism to push changes in the IaC source to the Azure environment, but also to pull changes made outside IaC back into source control. By having that feedback loop in place, we can ensure that:

- The environment described in source control always reflects the actual state of the Azure Subscriptions.
- Changes made manually are not inadvertently rolled back by the next automated deployment of a resource

#### Definition of Done (DoD)

- Changes made OOB (only for Platform resources) enlisted in Section #1 are tracked in Git.
- Configuration Drifts should surface just like any other pull request for repo owners to determine based on repo level policy whether to roll-back or roll-forward changes - interactively (with human intervention) or automatically.


# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
