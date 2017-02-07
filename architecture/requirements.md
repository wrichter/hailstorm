# Requirement Overview
(High-Level) requirements that are addressed with this setup.

## System context
List of actors / external systems
* (Human) Demonstrator, acting as
  * Consumer
  * Approver / Manager
  * Developer
  * Administrator
* (System) RH Subscription Management
* (System) RH Content Delivery Network
* (System) RH Container Registry
* (System) Upstream DNS

## Functional Requirements
* R01 - Include most of the RH Product Portfolio. In case of functional overlap, focus on the more common product (e.g. IPA vs. Certificate Server).
* R02 - Demonstrate product integrations. The idea is to show that 1+1>2, otherwise the result is just a set of parallel product/feature demos.
* R03 - Allow the setup to be brought up in different environments (IP Address ranges, DNS domains, ...)

## Non-Functional Requirements / Constraints
* NFR01 - Prioritize on "day in the life" storytelling. Features / technology aspects which are not visible in a demo or where a business benefit cannot be easily shown are of low priority.
* NFR02 - Ensure that the resulting setup stays current relative to GA product versions.
* NFR03 - Make the setup and updates to the setup easily transportable to allow it to be used in customer or partner environments, at trade shows, etc.

## Stakeholder Requests
Ideas, wishes, etc... which have been voiced but are not promoted to requirements yet. This may be due to lack of review, conflicts with the existing set of requirements or other reasons.
* SR01 - enable setup on a set of smaller nodes since it makes it easier for others/partners/etc... to provide such an infrastructure.
